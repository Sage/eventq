module EventQ
  module Amazon
    class QueueClient

      def initialize(options = {})
        invalid_keys = options.keys - [:sns_keep_alive_timeout, :sns_continue_timeout ]
        raise(OptionParser::InvalidOption, invalid_keys) unless invalid_keys.empty?

        @sns_keep_alive_timeout = options[:sns_keep_alive_timeout] || 30
        @sns_continue_timeout = options[:sns_continue_timeout] || 15
      end

      # Returns the AWS SQS Client
      def sqs
        @sqs ||= sqs_client
      end

      # Returns the AWS SNS Client
      def sns
        @sns ||= sns_client
      end

      def get_queue_arn(queue)
        _, arn = get_queue_url(queue)
        arn
      end

      def create_topic_arn(event_type)
        _event_type = EventQ.create_event_type(event_type)
        response = sns.create_topic(name: aws_safe_name(_event_type))
        return response.topic_arn
      end
      alias :get_topic_arn :create_topic_arn

      # Returns the URL and ARN of the queue. The queue will be created when it does
      #
      # @param queue [EventQ::Queue]
      # @return url,arn [Array]
      def get_queue_url_arn(queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        response= sqs.get_queue_url(
          queue_name: aws_safe_name(_queue_name)
        )
        result = sqs.get_queue_attributes({queue_url: response.queue_url, attribute_names: ['QueueArn']})

        return response.queue_url, result.attributes['QueueArn']
      end
      alias :get_queue_url :get_queue_url_arn

      def aws_safe_name(name)
        return name[0..79].gsub(/[^a-zA-Z\d_\-]/,'')
      end

      private

      def custom_endpoint(service)
        aws_env = ENV["AWS_#{service.upcase}_ENDPOINT"].to_s.dup
        aws_env.strip!
        { endpoint: aws_env } unless aws_env.empty?
      end

      def sqs_client
        options = custom_endpoint('sqs')
        options.merge!(verify_checksums: false) if options

        if options
          Aws::SQS::Client.new(options)
        else
          Aws::SQS::Client.new
        end
      end

      def sns_client
        custom_endpoint('sns')
        options = {
          http_idle_timeout: @sns_keep_alive_timeout,
          http_continue_timeout: @sns_continue_timeout
        }
        endpoint = custom_endpoint('sns')
        options.merge!(endpoint) if endpoint

        Aws::SNS::Client.new(options)
      end
    end
  end
end
