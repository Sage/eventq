class RabbitMqSubscriptionManager

  def initialize
    @client = RabbitMqQueueClient.new
    @queue_manager = RabbitMqQueueManager.new
    @event_raised_exchange = EventRaisedExchange.new
  end

  def subscribe(event_type, queue)

    channel = @client.get_channel
    queue = @queue_manager.get_queue(channel, queue)
    exchange = @queue_manager.get_exchange(channel, @event_raised_exchange)

    queue.bind(exchange, :routing_key => event_type)
  end

  def unsubscribe(queue)

    channel = @client.get_channel

    queue = @queue_manager.get_queue(channel, queue)
    exchange = @queue_manager.get_exchange(channel, @event_raised_exchange)

    queue.unbind(exchange)
  end

end