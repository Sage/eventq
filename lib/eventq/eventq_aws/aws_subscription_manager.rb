# frozen_string_literal: true

module EventQ
  module Amazon
    class SubscriptionManager

      def initialize(options)
        mandatory = [:client, :queue_manager]
        missing = mandatory - options.keys
        raise "[#{self.class}] - Missing options #{missing} must be specified." unless missing.empty?

        @client = options[:client]
        @manager = options[:queue_manager]
      end

      def subscribe(event_type, queue)
        topic_arn = @client.sns_helper.create_topic_arn(event_type)

        q = @manager.get_queue(queue)
        queue_arn = @client.sqs_helper.get_queue_arn(queue)

        @client.sqs.set_queue_attributes(
          {
            queue_url: q,
            attributes:
              {
                'Policy' => queue_policy(queue_arn)
              }
          }
        )

        @client.sns.subscribe({
                                  topic_arn: topic_arn,
                                  protocol: 'sqs',
                                  endpoint: queue_arn
                              })
        EventQ.logger.debug do
          "[#{self.class} #subscribe] - Subscribing Queue: #{queue.name} to topic_arn: #{topic_arn}, endpoint: #{queue_arn}"
        end

        true
      end

      def unsubscribe(queue)
        raise "[#{self.class}] - Not implemented. Please unsubscribe the queue from the topic inside the AWS Management Console."
      end

      def queue_policy(queue_arn)
'{
  "Version": "2012-10-17",
  "Id": "SNStoSQS",
  "Statement": [
    {
      "Sid":"rule1",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "' + queue_arn + '"
    }
  ]
}'
      end
    end
  end
end
