# frozen_string_literal: true

module EventQ
  module Amazon
    class CalculateVisibilityTimeout
      def call(retry_attempts:, retry_delay:, retry_back_off_grace:, max_retry_delay:, allow_retry_back_off:)
        retry_attempts = retry_attempts - retry_back_off_grace
        retry_attempts = 1 if retry_attempts < 1

        if allow_retry_back_off
          visibility_timeout = (retry_delay * retry_attempts) / 1000
          if visibility_timeout > (max_retry_delay / 1000)
            EventQ.logger.debug { "[#{self.class}] - Max message back off retry delay reached." }
            visibility_timeout = max_retry_delay / 1000
          end
        else
          visibility_timeout = retry_delay / 1000
        end

        if visibility_timeout > 43200
          EventQ.logger.debug { "[#{self.class}] - AWS max visibility timeout of 12 hours has been exceeded. Setting message retry delay to 12 hours." }
          visibility_timeout = 43200
        end

        visibility_timeout
      end
    end
  end
end