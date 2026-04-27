module EventQ
  module Amazon
    # Implements a general interface to raise an event
    # EventQ::RabbitMq::EventQClient is the sister-class which does the same for RabbitMq
    class EventQClient
      def initialize(options)
        raise ':client (QueueClient) must be specified.'.freeze if options[:client].nil?

        @client = options[:client]

        @serialization_manager = EventQ::SerializationProviders::Manager.new
        @signature_manager = EventQ::SignatureProviders::Manager.new

        # this hash is used to record known event types:
        # key = event_type / name
        # value = topic arn
        @known_event_types = {}
      end

      # Returns true if the event has already been registerd, or false
      # otherwise.
      #
      # @param [String] event_type
      # @param [String] region
      #
      # @return [Boolean]
      def registered?(event_type, region = nil)
        topic_key = "#{region}:#{event_type}"
        @known_event_types.key?(topic_key)
      end

      # Registers the event event_type and returns its topic arn.
      #
      # @param [String] event_type
      # @param [String] region
      #
      # @return [String]
      def register_event(event_type, region = nil)
        topic_key = "#{region}:#{event_type}"
        return @known_event_types[topic_key] if registered?(event_type, region)

        topic_arn = @client.sns_helper(region).create_topic_arn(event_type, region)
        @known_event_types[topic_key] = topic_arn
        topic_arn
      end

      def publish(topic:, event:, context: {}, region: nil)
        raise_event(topic, event, context, region)
      end

      def publish_batch(topic:, events:, context: {}, region: nil)
        raise_events_batch(topic, events, context, region)
      end

      def raise_event(event_type, event, context = {}, region = nil)
        topic_arn = register_event(event_type, region)

        with_prepared_message(event_type, event, context) do |message|
          response = @client.sns(region).publish(
            topic_arn: topic_arn,
            message: message,
            subject: event_type
          )

          EventQ.logger.debug do
            "[#{self.class} #raise_event] - Published to SNS with topic_arn: #{topic_arn}" \
              " | event_type: #{event_type} | Message: #{message}"
          end

          response
        end
      end

      def raise_events_batch(event_type, events, context = {}, region = nil)
        topic_arn = register_event(event_type, region)
        publish_entries = prepare_batch_entries(event_type, events, context)

        message_ids = []
        # AWS SNS PublishBatch API allows a maximum of 10 messages per batch
        publish_entries.each_slice(10) do |batch_entries|
          response = @client.sns(region).publish_batch(
            topic_arn: topic_arn,
            publish_batch_request_entries: batch_entries
          )

          EventQ.logger.debug do
            "[#{self.class} #raise_events_batch] - Published batch to SNS with topic_arn: #{topic_arn}" \
              " | event_type: #{event_type} | batch_size: #{batch_entries.length}"
          end

          message_ids.concat(response.successful.map(&:message_id))
        end

        message_ids
      end

      def raise_event_in_queue(event_type, event, queue, delay, context = {})
        queue_url = @client.sqs_helper.get_queue_url(queue)
        with_prepared_message(event_type, event, context) do |message|
          response = @client.sqs.send_message(
            queue_url: queue_url,
            message_body: sqs_message_body_for(message),
            delay_seconds: delay
          )

          EventQ.logger.debug do
            "[#{self.class} #raise_event_in_queue] - Raised event to SQS queue: #{queue_url}" \
              " | event_type: #{event_type} | Message: #{message}"
          end

          response
        end
      end

      def new_message
        EventQ::QueueMessage.new
      end

      private

      def prepare_batch_entries(event_type, events, default_context)
        events.each_with_index.map do |entry, index|
          event, context = batch_entry_values(entry, default_context)

          {
            id: "msg-#{index}",
            message: prepared_message(event_type, event, context),
            subject: event_type
          }
        end
      end

      def batch_entry_values(entry, default_context)
        return [entry[:event], entry.fetch(:context, default_context)] if entry.is_a?(Hash) && entry.key?(:event)

        [entry, default_context]
      end

      def prepared_message(event_type, event, context)
        build_queue_message(event_type, event, context).yield_self { |qm| serialized_message(qm) }
      end

      def build_queue_message(event_type, event, context)
        qm = new_message
        qm.content = event
        qm.type = event_type
        qm.context = context
        qm.content_type = event.class.to_s
        if event.respond_to? :Correlation
          qm.correlation_trace_id = event.Correlation['Trace']
          qm.Correlation = event.Correlation
        end

        unless EventQ::Configuration.signature_secret.nil?
          provider = @signature_manager.get_provider(EventQ::Configuration.signature_provider)
          qm.signature = provider.write(message: qm, secret: EventQ::Configuration.signature_secret)
        end

        qm
      end

      def with_prepared_message(event_type, event, context)
        message = prepared_message(event_type, event, context)

        response = yield(message)

        EventQ.log(:debug, "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type}.")

        response.message_id
      end

      def serialized_message(queue_message)
        serialization_provider = @serialization_manager.get_provider(EventQ::Configuration.serialization_provider)

        serialization_provider.serialize(queue_message)
      end

      def sqs_message_body_for(payload_message)
        JSON.dump(EventQ::Amazon::QueueWorker::MESSAGE => payload_message)
      end
    end
  end
end
