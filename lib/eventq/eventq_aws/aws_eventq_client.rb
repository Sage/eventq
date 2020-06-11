module EventQ
  module Amazon
    # Implements a general interface to raise an event
    # EventQ::RabbitMq::EventQClient is the sister-class which does the same for RabbitMq
    class EventQClient

      def initialize(options)

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'.freeze
        end

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

      def raise_event(event_type, event, context = {}, region = nil)
        register_event(event_type, region)

        with_prepared_message(event_type, event, context) do |message|
          topic_arn = topic_arn(event_type, region)
          response = @client.sns(region).publish(
            topic_arn: topic_arn,
            message: message,
            subject: event_type
          )

          EventQ.logger.debug do
            "[#{self.class} #raise_event] - Published to SNS with topic_arn: #{topic_arn} | event_type: #{event_type} | Message: #{message}"
          end

          response
        end
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
            "[#{self.class} #raise_event_in_queue] - Raised event to SQS queue: #{queue_url} | event_type: #{event_type} | Message: #{message}"
          end

          response
        end
      end

      def new_message
        EventQ::QueueMessage.new
      end

      private

      def with_prepared_message(event_type, event, context)
        qm = new_message
        qm.content = event
        qm.type = event_type
        qm.context = context
        qm.content_type = event.class.to_s

        if EventQ::Configuration.signature_secret != nil
          provider = @signature_manager.get_provider(EventQ::Configuration.signature_provider)
          qm.signature = provider.write(message: qm, secret: EventQ::Configuration.signature_secret)
        end

        message = serialized_message(qm)

        response = yield(message)

        EventQ.log(:debug, "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type}.")

        response.message_id
      end

      def serialized_message(queue_message)
        serialization_provider = @serialization_manager.get_provider(EventQ::Configuration.serialization_provider)

        serialization_provider.serialize(queue_message)
      end

      def topic_arn(event_type, region = nil)
        @client.sns_helper(region).get_topic_arn(event_type, region)
      end

      def sqs_message_body_for(payload_message)
        JSON.dump(EventQ::Amazon::QueueWorker::MESSAGE => payload_message)
      end
    end
  end
end
