# frozen_string_literal: true

module EventQ
  module Amazon
    class CalculateVisibilityTimeout
      def initialize(max_timeout:, logger: EventQ.logger)
        @max_timeout = max_timeout
        @logger      = logger
      end

      # Calculate Visibility Timeout
      #
      # @param retry_attempts [Integer] Current retry
      # @param retry_delay [Integer] Amount of time to wait until retry in ms
      # @param retry_back_off_grace [Integer] Amount of retries to wait before starting to backoff
      # @param max_retry_delay [Integer] Maximum amount of time a retry will take in ms
      # @param allow_retry_back_off [Bool] Enables/Disables backoff strategy
      # @return [Integer] the calculated visibility timeout in seconds
      def call(retry_attempts:, retry_delay:, retry_back_off_grace:, max_retry_delay:, allow_retry_back_off:)
        @retry_attempts       = retry_attempts
        @retry_delay          = retry_delay
        @retry_back_off_grace = retry_back_off_grace
        @max_retry_delay      = max_retry_delay
        @allow_retry_back_off = allow_retry_back_off

        if allow_retry_back_off && retry_past_grace_period?
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
        @retry_attempts >= @retry_back_off_grace
      end

      def timeout_without_back_off
        ms_to_seconds(@retry_delay)
      end

      def timeout_with_back_off
        factor = @retry_attempts - @retry_back_off_grace

        visibility_timeout = ms_to_seconds(@retry_delay * factor)
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