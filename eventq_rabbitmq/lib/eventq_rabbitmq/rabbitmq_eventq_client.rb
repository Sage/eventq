require 'oj'

class RabbitMqEventQClient

  def initialize(options={})
    @client = RabbitMqQueueClient.new
    @queue_manager = RabbitMqQueueManager.new
    @event_raised_exchange = EventRaisedExchange.new
    @subscription_manager = options[:subscription_manager] || RabbitMqSubscriptionManager.new
  end

  def raise(event_type, event)
    channel = @client.get_channel
    ex = queue_manager.get_exchange(channel, event_raised_exchange)

    subscription_manager.subscribe(event_type, DefaultQueue.new)

    qm = QueueMessage.new
    qm.content = event
    qm.type = event_type

    message = Oj.dump(qm)

    ex.publish(message, :routing_key => event_type)
  end

  private

  attr_reader :subscription_manager, :queue_manager, :event_raised_exchange
end
