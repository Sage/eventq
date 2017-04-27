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

        #this array is used to record known event types
        @known_event_types = []

      end

      def registered?(event_type)
        @known_event_types.include?(event_type)
      end

      def register_event(event_type)
        if registered?(event_type)
          return true
        end

        @client.create_topic_arn(event_type)
        @known_event_types << event_type
        true
      end

      def raise_event(event_type, event)
        register_event(event_type)

        with_prepared_message(event_type, event) do |message|

          response = @client.sns.publish(
            topic_arn: topic_arn(event_type),
            message: message,
            subject: event_type
          )

          EventQ.logger.debug do
            "[#{self.class} #raise_event] - Published to SNS with topic_arn: #{topic_arn(event_type)} | event_type: #{event_type} | Message: #{message}"
          end

          response
        end
      end

      def raise_event_in_queue(event_type, event, queue, delay)
        queue_url = @client.get_queue_url(queue)
        with_prepared_message(event_type, event) do |message|

          response = @client.sqs.send_message(
            queue_url: queue_url,
            message_body: message,
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

      def with_prepared_message(event_type, event)
        qm = new_message
        qm.content = event
        qm.type = event_type

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

      def topic_arn(event_type)
        @client.get_topic_arn(event_type)
      end
    end
  end
end
