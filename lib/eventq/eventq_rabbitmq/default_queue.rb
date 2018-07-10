module EventQ
  module RabbitMq
    class DefaultQueue < Queue
      def initialize
        @name = 'Default'.freeze
        @allow_retry = false
        @max_retry_attempts = 1
      end
    end
  end
end

