# frozen_string_literal: true

module EventQ
  module Amazon
    class QueueManager

      VISIBILITY_TIMEOUT = 'VisibilityTimeout'
      MESSAGE_RETENTION_PERIOD = 'MessageRetentionPeriod'

      def initialize(options)
        mandatory = [:client]
        missing = mandatory - options.keys
        raise "[#{self.class}] - Missing options #{missing} must be specified." unless missing.empty?

        @client = options[:client]
        @visibility_timeout = options[:visibility_timeout] || 300 #5 minutes
        @message_retention_period = options[:message_retention_period] || 1209600 #14 days (max aws value)

      end

      def get_queue(queue)
        if queue.dlq
          queue_exists?(queue.dlq) ? update_queue(queue.dlq) : create_queue(queue.dlq)
        end

        queue_exists?(queue) ? update_queue(queue) : create_queue(queue)
      end

      def create_queue(queue)
        @client.sqs_helper.create_queue(queue, queue_attributes(queue))
      end

      def drop_queue(queue)
        @client.sqs_helper.drop_queue(queue)
      end

      def drop_topic(event_type)
        @client.sns_helper.drop_topic(event_type)
      end

      def topic_exists?(event_type)
        !!@client.sns_helper.get_topic_arn(event_type)
      end

      def queue_exists?(queue)
        !!@client.sqs_helper.get_queue_url(queue)
      end

      def update_queue(queue)
        @client.sqs_helper.update_queue(queue, queue_attributes(queue))
      end

      def queue_attributes(queue)
        attributes = {
          VISIBILITY_TIMEOUT => @visibility_timeout.to_s,
          MESSAGE_RETENTION_PERIOD => @message_retention_period.to_s
        }

        if queue.dlq
          dlq_arn = @client.sqs_helper.get_queue_arn(queue.dlq)
          attributes['RedrivePolicy'] = %Q({"maxReceiveCount":"#{queue.max_receive_count}","deadLetterTargetArn":"#{dlq_arn}"})
        end

        attributes
      end
    end
  end
end
