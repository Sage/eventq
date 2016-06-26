module EventQ
  module Aws
    class EventQClient
      def initialize
        @client = QueueClient.new
      end

      def raise(event_type, event)

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

        return response.message_id

      end

    end
  end
end
