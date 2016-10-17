module EventQ
  module Amazon
    class EventQClient

      def initialize(options)

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'.freeze
        end

        @client = options[:client]

        @serialization_manager = EventQ::SerializationProviders::Manager.new

      end

      def raise_event(event_type, event)

        topic_arn = @client.get_topic_arn(event_type)

        qm = new_message
        qm.content = event
        qm.type = event_type

        serialization_provider = @serialization_manager.get_provider(EventQ::Configuration.serialization_provider)

        message = serialization_provider.serialize(qm)

        response = @client.sns.publish({
                                           topic_arn: topic_arn,
                                           message: message,
                                           subject: event_type
                                       })

        EventQ.log(:debug, "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type}.")

        return response.message_id

      end

      def new_message
        EventQ::QueueMessage.new
      end

    end
  end
end
