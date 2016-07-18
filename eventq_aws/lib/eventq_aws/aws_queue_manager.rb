module EventQ
  module Amazon
    class QueueManager

      @@dead_letter_queue = 'dead_letter_archive'

      def initialize(options)

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'
        end

        @client = options[:client]
      end

      def get_queue(queue)

        if queue_exists?(queue)
          update_queue(queue)
        else
          create_queue(queue)
        end

      end

      def create_queue(queue)
        response = @client.sqs.create_queue({
                                                queue_name: queue.name,
                                                attributes: {
                                                    'VisibilityTimeout' => (queue.retry_delay / 1000).to_s
                                                }
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

      def queue_exists?(queue)
        return @client.sqs.list_queues({ queue_name_prefix: queue.name }).queue_urls.length > 0
      end

      def update_queue(queue)
        url = @client.get_queue_url(queue)
        @client.sqs.set_queue_attributes({
                                             queue_url: url, # required
                                              attributes: {
                                                'VisibilityTimeout' => (queue.retry_delay / 1000).to_s
                                              }
                                          })
        return url
      end

    end
  end
end
