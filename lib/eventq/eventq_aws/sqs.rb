# frozen_string_literal: true

module EventQ
  module Amazon
    # Helper SQS class to handle the API calls
    class SQS
      @@queue_arns = Concurrent::Hash.new
      @@queue_urls = Concurrent::Hash.new

      attr_reader :sqs

      def initialize(client)
        @sqs = client
      end

      # Create a new queue.
      def create_queue(queue, attributes = {})
        _queue_name = EventQ.create_queue_name(queue.name)

        url = get_queue_url(queue)
        unless url
          response = sqs.create_queue(
            {
              queue_name: _queue_name,
              attributes: attributes
            }
          )
          url = response.queue_url
          @@queue_urls[_queue_name] = url
        end

        url
      end

      # Update a queue
      def update_queue(queue, attributes = {})
        url = get_queue_url(queue)
        sqs.set_queue_attributes(
          {
            queue_url: url, # required
            attributes: attributes
          }
        )

        url
      end

      # Returns the ARN of a queue.  If none exists, nil will be returned.
      #
      # @param queue [EventQ::Queue]
      # @return ARN [String]
      def get_queue_arn(queue)
        _queue_name = EventQ.create_queue_name(queue.name)

        arn = @@queue_arns[_queue_name]
        unless arn
          url = get_queue_url(queue)
          if url
            response = sqs.get_queue_attributes({queue_url: url, attribute_names: ['QueueArn']})
            arn = response.attributes['QueueArn']
          end
        end

        arn
      end

      # Returns the URL of the queue. If none exists, nil will be returned.
      #
      # @param queue [EventQ::Queue]
      # @return URL [String]
      def get_queue_url(queue)
        _queue_name = EventQ.create_queue_name(queue.name)

        url = @@queue_urls[_queue_name]
        unless url
          begin
            response= sqs.get_queue_url(
                queue_name: aws_safe_name(_queue_name)
            )
            url = response.queue_url
          rescue Aws::SQS::Errors::NonExistentQueue

          end

          @@queue_urls[_queue_name] = url if url
        end

        url
      end

      def drop_queue(queue)
        q = get_queue_url(queue)
        sqs.delete_queue(queue_url: q)

        _queue_name = EventQ.create_queue_name(queue.name)
        @@queue_urls.delete(_queue_name)
        @@queue_arns.delete(_queue_name)

        true
      end

      def aws_safe_name(name)
        return name[0..79].gsub(/[^a-zA-Z\d_\-]/,'')
      end
    end
  end
end
