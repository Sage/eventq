module EventQ
  module RabbitMq
    class EventQClient

      def initialize(options={})

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'
        end

        @client = options[:client]
        @queue_manager = QueueManager.new
        @event_raised_exchange = EventRaisedExchange.new
        @subscription_manager = options[:subscription_manager]
      end

      def raise_event(event_type, event)
        channel = @client.get_channel
        ex = @queue_manager.get_exchange(channel, @event_raised_exchange)

        @subscription_manager.subscribe(event_type, DefaultQueue.new)

        qm = EventQ::QueueMessage.new
        qm.content = event
        qm.type = event_type

        message = Oj.dump(qm)

        ex.publish(message, :routing_key => event_type)
        channel.close

        return true
      end

    end
  end
end

