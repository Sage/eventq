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

        topic_arn = @client.get_topic_arn(event_type)

        qm = EventQ::QueueMessage.new
        qm.content = event
        qm.type = event_type

        message = Oj.dump(qm)

        response = @client.sns.publish({
                                           topic_arn: topic_arn,
                                           message: message,
                                           subject: event_type
                                       })

        EventQ.logger.debug "[EVENTQ_AWS] - Raised event. Message: #{message} | Type: #{event_type}."

        return response.message_id

      end

    end
  end
end
