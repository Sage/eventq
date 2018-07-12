# frozen_string_literal: true

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

      def sqs_helper
        @sqs_helper ||= Amazon::SQS.new(sqs)
      end

      def sns_helper
        @sns_helper ||= Amazon::SNS.new(sns)
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
