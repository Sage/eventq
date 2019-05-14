module EventQ
  module Exceptions
    # Error for when an event type is not found by the relevant adapters
    # For AWS SNS that would be a Topic
    # For RabbitMq that would be an Exchange.
    class EventTypeNotFound < StandardError
      def initialize(message)
        super(message)
      end
    end
  end
end
