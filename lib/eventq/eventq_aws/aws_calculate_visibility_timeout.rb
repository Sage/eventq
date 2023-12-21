# frozen_string_literal: true

module EventQ
  module Amazon
    # Class responsible to know how to calculate message Visibility Timeout for Amazon SQS
    class CalculateVisibilityTimeout
      def initialize(max_timeout:, logger: EventQ.logger)
        @max_timeout = seconds_to_ms(max_timeout)
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
      # @option retry_jitter_ratio [Integer] Ratio of how much jitter to apply to the backoff retry
      # @option retry_delay [Integer] Amount of time to wait until retry in ms
      # @return [Integer] the calculated visibility timeout in seconds
      def call(retry_attempts:, queue_settings:)
        @retry_attempts = retry_attempts

        @allow_retry_back_off       = queue_settings.fetch(:allow_retry_back_off)
        @allow_exponential_back_off = queue_settings.fetch(:allow_exponential_back_off)
        @max_retry_delay            = queue_settings.fetch(:max_retry_delay)
        @retry_back_off_grace       = queue_settings.fetch(:retry_back_off_grace)
        @retry_back_off_weight      = queue_settings.fetch(:retry_back_off_weight)
        @retry_jitter_ratio         = queue_settings.fetch(:retry_jitter_ratio)
        @retry_delay                = queue_settings.fetch(:retry_delay)

        visibility_timeout = if @allow_retry_back_off && retry_past_grace_period?
          timeout_with_back_off
        else
          timeout_without_back_off
        end

        visibility_timeout = apply_jitter(visibility_timeout) if @retry_jitter_ratio > 0

        ms_to_seconds(visibility_timeout)
      end

      private

      attr_reader :logger

      def retry_past_grace_period?
        @retry_attempts > @retry_back_off_grace
      end

      def timeout_without_back_off
        @retry_delay
      end

      def timeout_with_back_off
        factor = @retry_attempts - @retry_back_off_grace
        weighted_retry_delay = @retry_delay * @retry_back_off_weight

        visibility_timeout = if @allow_exponential_back_off
          weighted_retry_delay * 2 ** (factor - 1)
        else
          weighted_retry_delay * factor
        end

        visibility_timeout = check_for_max_retry_delay(visibility_timeout)
        check_for_max_timeout(visibility_timeout)
      end

      def apply_jitter(visibility_timeout)
        ratio = @retry_jitter_ratio / 100.0
        min_visibility_timeout = (visibility_timeout * (1 - ratio)).to_i
        rand(min_visibility_timeout..visibility_timeout)
      end

      def ms_to_seconds(value)
        value / 1000
      end

      def seconds_to_ms(value)
        value * 1000
      end

      def check_for_max_retry_delay(visibility_timeout)
        return visibility_timeout if visibility_timeout <= @max_retry_delay

        logger.debug do
          "[#{self.class}] - Max message back off retry delay reached: #{ms_to_seconds(@max_retry_delay)}"
        end

        @max_retry_delay
      end

      def check_for_max_timeout(visibility_timeout)
        return visibility_timeout if visibility_timeout <= @max_timeout

        logger.debug do
          "[#{self.class}] - AWS max visibility timeout of 12 hours has been exceeded. "\
          "Setting message retry delay to 12 hours."
        end

        @max_timeout
      end
    end
  end
end
