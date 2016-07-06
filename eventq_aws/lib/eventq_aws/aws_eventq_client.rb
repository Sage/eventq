module EventQ
  module Amazon
    class EventQClient

      def initialize(options)

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'
        end

        @client = options[:client]

      end

      def raise_event(event_type, event)

        topic_arn = @client.get_topic_arn(event_type_safe(event_type))

        qm = EventQ::QueueMessage.new
        qm.content = event
        qm.type = event_type

        message = Oj.dump(qm)

        response = @client.sns.publish({
                                           topic_arn: topic_arn,
                                           message: message,
                                           subject: event_type
                                       })

        return response.message_id

      end

      def event_type_safe(event_type)
        event_type.gsub(':', '')
      end

    end
  end
end
