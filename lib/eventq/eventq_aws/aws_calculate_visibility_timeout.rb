# frozen_string_literal: true

module EventQ
  module Amazon
    # Class responsible to know how to calculate message Visibility Timeout for Amazon SQS
    class CalculateVisibilityTimeout
      def initialize(max_timeout:, logger: EventQ.logger)
        @max_timeout = max_timeout
        @logger      = logger
      end

      # Calculate Visibility Timeout
      #
      # @param retry_attempts [Integer] Current retry
      # @param queue_settings [Hash] Queue settings
      # @option allow_retry_back_off [Bool] Enables/Disables backoff strategy
      # @option allow_exponential_back_off [Bool] Enables/Disables exponential backoff strategy
      # @option max_retry_delay [Integer] Maximum amount of time a retry will take in ms
      # @option retry_back_off_grace [Integer] Amount of retries to wait before starting to backoff
      # @option retry_back_off_weight [Integer] Multiplier for the backoff retry
      # @option retry_delay [Integer] Amount of time to wait until retry in ms
      # @return [Integer] the calculated visibility timeout in seconds
      def call(retry_attempts:, queue_settings:)
        @retry_attempts = retry_attempts

        @allow_retry_back_off       = queue_settings.fetch(:allow_retry_back_off)
        @allow_exponential_back_off = queue_settings.fetch(:allow_exponential_back_off, false)
        @max_retry_delay            = queue_settings.fetch(:max_retry_delay)
        @retry_back_off_grace       = queue_settings.fetch(:retry_back_off_grace)
        @retry_back_off_weight      = queue_settings.fetch(:retry_back_off_weight)
        @retry_delay                = queue_settings.fetch(:retry_delay)

        if @allow_retry_back_off && retry_past_grace_period?
          visibility_timeout = timeout_with_back_off
          visibility_timeout = check_for_max_timeout(visibility_timeout)
        else
          visibility_timeout = timeout_without_back_off
        end

        visibility_timeout
      end

      private

      attr_reader :logger

      def retry_past_grace_period?
        @retry_attempts > @retry_back_off_grace
      end

      def timeout_without_back_off
        ms_to_seconds(@retry_delay)
      end

      def timeout_with_back_off
        factor = @retry_attempts - @retry_back_off_grace

        visibility_timeout = if @allow_exponential_back_off
          ms_to_seconds(@retry_delay * @retry_back_off_weight * 2 ** (factor - 1))
        else
          ms_to_seconds(@retry_delay * @retry_back_off_weight * factor)
        end

        max_retry_delay = ms_to_seconds(@max_retry_delay)

        if visibility_timeout > max_retry_delay
          logger.debug { "[#{self.class}] - Max message back off retry delay reached: #{max_retry_delay}" }
          visibility_timeout = max_retry_delay
        end

        visibility_timeout
      end

      def ms_to_seconds(value)
        value / 1000
      end

      def check_for_max_timeout(visibility_timeout)
        if visibility_timeout > @max_timeout
          logger.debug { "[#{self.class}] - AWS max visibility timeout of 12 hours has been exceeded. Setting message retry delay to 12 hours." }
          visibility_timeout = @max_timeout
        end
        visibility_timeout
      end
    end
  end
end
