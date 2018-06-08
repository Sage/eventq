module EventQ
  module Amazon
    class QueueManager

      VISIBILITY_TIMEOUT = 'VisibilityTimeout'.freeze
      MESSAGE_RETENTION_PERIOD = 'MessageRetentionPeriod'.freeze

      def initialize(options)

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'.freeze
        end

        @client = options[:client]

        @visibility_timeout = 300 #5 minutes
        if options.key?(:visibility_timeout)
          @visibility_timeout = options[:visibility_timeout]
        end

        @message_retention_period = 1209600 #14 days (max aws value)
        if options.key?(:message_retention_period)
          @message_retention_period = options[:message_retention_period]
        end

      end

      def get_queue(queue)
        if queue.dlq
          queue_exists?(queue.dlq) ? update_queue(queue.dlq) : create_queue(queue.dlq)
        end

        queue_exists?(queue) ? update_queue(queue) : create_queue(queue)
      end

      def create_queue(queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        response = @client.sqs.create_queue({
          queue_name: _queue_name,
          attributes: queue_attributes(queue)
        })

        return response.queue_url
      end

      def drop_queue(queue)

        q = get_queue(queue)

        @client.sqs.delete_queue({ queue_url: q})

        return true

      end

      def drop_topic(event_type)
        topic_arn = @client.get_topic_arn(event_type)
        @client.sns.delete_topic({ topic_arn: topic_arn})

        return true
      end

      def topic_exists?(event_type)
        topic_arn = @client.get_topic_arn(event_type)

        begin
        @client.sns.get_topic_attributes({ topic_arn: topic_arn })
        rescue
          return false
        end
        return true
      end

      def queue_exists?(queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        return @client.sqs.list_queues({ queue_name_prefix: _queue_name }).queue_urls.length > 0
      end

      def update_queue(queue)
        url = @client.get_queue_url(queue)
        @client.sqs.set_queue_attributes({
          queue_url: url, # required
          attributes: queue_attributes(queue)
        })
        return url
      end

      def queue_attributes(queue)
        attributes = {
          VISIBILITY_TIMEOUT => @visibility_timeout.to_s,
          MESSAGE_RETENTION_PERIOD => @message_retention_period.to_s
        }

        if queue.dlq
          dlq_arn = @client.get_queue_arn(queue.dlq)
          attributes['RedrivePolicy'] = %Q({"maxReceiveCount":"#{queue.max_receive_count}","deadLetterTargetArn":"#{dlq_arn}"})
        end

        attributes
      end
    end
  end
end
