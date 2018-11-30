# frozen_string_literal: true

module EventQ
  module Amazon
    class CalculateVisibilityTimeout
      def initialize(max_timeout:)
        @max_timeout = max_timeout
      end

      def call(retry_attempts:, retry_delay:, retry_back_off_grace:, max_retry_delay:, allow_retry_back_off:)
        retry_attempts = apply_back_off_grace(retry_attempts, retry_back_off_grace)

        return timeout_without_back_off(retry_delay) unless allow_retry_back_off

        visibility_timeout = timeout_with_back_off(retry_delay, retry_attempts, max_retry_delay)

        if visibility_timeout > @max_timeout
          EventQ.logger.debug { "[#{self.class}] - AWS max visibility timeout of 12 hours has been exceeded. Setting message retry delay to 12 hours." }
          visibility_timeout = @max_timeout
        end

        visibility_timeout
      end

      private

      def timeout_without_back_off(retry_delay)
        retry_delay / 1000
      end

      def apply_back_off_grace(retry_attempts, retry_back_off_grace)
        retry_attempts = retry_attempts - retry_back_off_grace
        retry_attempts = 1 if retry_attempts < 1
        retry_attempts
      end

      def timeout_with_back_off(retry_delay, retry_attempts, max_retry_delay)
        visibility_timeout = (retry_delay * retry_attempts) / 1000
        if visibility_timeout > (max_retry_delay / 1000)
          EventQ.logger.debug { "[#{self.class}] - Max message back off retry delay reached." }
          visibility_timeout = max_retry_delay / 1000
        end
        visibility_timeout
      end
    end
  end
end