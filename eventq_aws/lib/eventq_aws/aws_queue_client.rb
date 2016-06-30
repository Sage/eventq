module EventQ
  module Aws
    class QueueClient

      attr_reader :sns
      attr_reader :sqs

      def initialize(options = {})

        if options.has_key?(:aws_key)
          Aws.config[:credentials] = Aws::Credentials.new(options[:aws_key], options[:aws_secret])
        end

        @sns = Aws::SNS::Client.new
        @sqs = Aws::SQS::Client.new

        @aws_account = options[:aws_account_number]
        @aws_region = options[:aws_region] || 'us-west-2'

        Aws.config[:region] = @aws_region

      end

      def get_topic_arn(event_type)
        #TODO: revisit this to create locally to improve performance
        response = @sns.create_topic({ name: event_type })
        return response.topic_arn
      end

      def get_queue_arn(queue)
        return "arn:aws:sqs:#{@aws_region}:#{@aws_account}:#{queue.name}"
      end

    end
  end
end
