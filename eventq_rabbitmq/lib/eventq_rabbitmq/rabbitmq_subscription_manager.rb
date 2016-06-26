module EventQ
  module RabbitMq
    class SubscriptionManager

      def initialize
        @client = QueueClient.new
        @queue_manager = QueueManager.new
        @event_raised_exchange = EventQ::EventRaisedExchange.new
      end

      def subscribe(event_type, queue)

        channel = @client.get_channel
        queue = @queue_manager.get_queue(channel, queue)
        exchange = @queue_manager.get_exchange(channel, @event_raised_exchange)

        queue.bind(exchange, :routing_key => event_type)

        return true
      end

      def unsubscribe(queue)

        channel = @client.get_channel

        queue = @queue_manager.get_queue(channel, queue)
        exchange = @queue_manager.get_exchange(channel, @event_raised_exchange)

        queue.unbind(exchange)

        return true
      end

    end
  end
end
