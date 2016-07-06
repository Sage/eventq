module EventQ
  module Amazon
    class QueueClient

      attr_reader :sns
      attr_reader :sqs

      def initialize(options = {})

        if options.has_key?(:aws_key)
          Aws.config[:credentials] = Aws::Credentials.new(options[:aws_key], options[:aws_secret])
        end

        if !options.has_key?(:aws_account_number)
          raise ':aws_account_number option must be specified.'
        end

        @aws_account = options[:aws_account_number]

        if options.has_key?(:aws_region)
          @aws_region = options[:aws_region]
          Aws.config[:region] = @aws_region
        else
          @aw_region = Aws.config[:region]
        end

        @sns = Aws::SNS::Client.new
        @sqs = Aws::SQS::Client.new

      end

      def get_topic_arn(event_type)
        return "arn:aws:sns:#{@aws_region}:#{@aws_account}:#{aws_safe_name(event_type)}"
      end

      def get_queue_arn(queue)
        return "arn:aws:sqs:#{@aws_region}:#{@aws_account}:#{aws_safe_name(queue.name)}"
      end

      def aws_safe_name(name)
        name.gsub(':', '')
      end

    end
  end
end
