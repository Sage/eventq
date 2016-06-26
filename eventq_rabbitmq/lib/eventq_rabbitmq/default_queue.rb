module EventQ
  module RabbitMq
    class DefaultQueue < Queue
      def initialize
        @name = 'Default'
        @allow_retry = false
        @max_retry_attempts = 1
      end
    end
  end
end

