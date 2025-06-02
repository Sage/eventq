# frozen_string_literal: true

module EventQ
  module Amazon
    class SubscriptionManager
      def initialize(options)
        mandatory = %i[client queue_manager]
        missing = mandatory - options.keys
        raise "[#{self.class}] - Missing options #{missing} must be specified." unless missing.empty?

        @client = options[:client]
        @manager = options[:queue_manager]
      end

      def subscribe(event_type, queue, topic_region = nil, queue_region = nil, topic_namespaces = [EventQ.namespace])
        if queue.isolated
          method = :get_topic_arn
        else
          method = :create_topic_arn
        end

        topic_arn = @client.sns_helper(topic_region).public_send(method, event_type, topic_region, topic_namespaces[0])
        raise Exceptions::EventTypeNotFound, "SNS topic not found, unable to subscribe to #{event_type}" unless topic_arn

        queue_arn = configure_queue(queue, queue_region)

        # subscribe the queue to the topic with the namespaces provided
        topic_namespaces.each do |namespace|
          namespaced_topic_arn = topic_arn.gsub(":#{EventQ.namespace}-", ":#{namespace}-")

          # create the sns topic - this method is idempotent & returns the topic arn if it already exists
          @client.sns_helper.create_topic_arn(event_type.delete('.'), nil, namespace) unless queue.isolated

          # skip subscribe if subscription for given queue/topic already exists
          # this is a workaround for a localstack issue: https://github.com/localstack/localstack/issues/933
          return true if existing_subscription?(queue_arn, namespaced_topic_arn)

          EventQ.logger.debug do
            "[#{self.class} #subscribe] - Subscribing Queue: #{queue.name} to topic_arn: #{namespaced_topic_arn}, endpoint: #{queue_arn}"
          end

          @client.sns(topic_region).subscribe(
            topic_arn: namespaced_topic_arn,
            protocol: 'sqs',
            endpoint: queue_arn
          )
        end

        true
      end

      def unsubscribe(_queue)
        raise "[#{self.class}] - Not implemented. Please unsubscribe the queue from the topic inside the AWS Management Console."
      end

      private

      def configure_queue(queue, region)
        q = @manager.get_queue(queue)
        queue_arn = @client.sqs_helper(region).get_queue_arn(queue)

        attributes = default_queue_attributes(q, queue_arn)
        @client.sqs(region).set_queue_attributes(attributes)
        queue_arn
      end

      def default_queue_attributes(queue, queue_arn)
        {
          queue_url: queue,
          attributes:
            {
              'Policy' => queue_policy(queue_arn)
            }
        }
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

      # check if there is an existing subscription for the given queue/topic
      def existing_subscription?(queue_arn, topic_arn)
        subscriptions = @client.sns.list_subscriptions.subscriptions
        subscriptions.any? { |subscription| subscription.topic_arn == topic_arn && subscription.endpoint == queue_arn }
      end
    end
  end
end
