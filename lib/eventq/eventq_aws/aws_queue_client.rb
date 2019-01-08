# frozen_string_literal: true

module EventQ
  module Amazon
    class QueueClient
      def initialize(options = {})
        invalid_keys = options.keys - %i[sns_keep_alive_timeout sns_continue_timeout]
        raise(OptionParser::InvalidOption, invalid_keys) unless invalid_keys.empty?

        @sns_keep_alive_timeout = options[:sns_keep_alive_timeout] || 30
        @sns_continue_timeout = options[:sns_continue_timeout] || 15
      end

      # Returns the AWS SQS Client
      def sqs(region = nil)
        if region.nil?
          @sqs ||= sqs_client
        else
          sqs_client(region)
        end
      end

      # Returns the AWS SNS Client
      def sns(region = nil)
        if region.nil?
          @sns ||= sns_client
        else
          sns_client(region)
        end
      end

      def sqs_helper(region = nil)
        if region.nil?
          @sqs_helper ||= Amazon::SQS.new(sqs)
        else
          Amazon::SQS.new(sqs_client(region))
        end
      end

      def sns_helper(region = nil)
        if region.nil?
          @sns_helper ||= Amazon::SNS.new(sns)
        else
          Amazon::SNS.new(sns_client(region))
        end
      end

      private

      def custom_endpoint(service)
        aws_env = ENV["AWS_#{service.upcase}_ENDPOINT"].to_s.dup
        aws_env.strip!
        { endpoint: aws_env } unless aws_env.empty?
      end

      def sqs_client(region = nil)
        options = custom_endpoint('sqs')
        options[:verify_checksums] = false if options
        options[:region] = region if region

        if options
          Aws::SQS::Client.new(options)
        else
          Aws::SQS::Client.new
        end
      end

      def sns_client(region = nil)
        custom_endpoint('sns')
        options = {
          http_idle_timeout: @sns_keep_alive_timeout,
          http_continue_timeout: @sns_continue_timeout
        }
        endpoint = custom_endpoint('sns')
        options.merge!(endpoint) if endpoint
        options[:region] = region if region

        Aws::SNS::Client.new(options)
      end
    end
  end
end
