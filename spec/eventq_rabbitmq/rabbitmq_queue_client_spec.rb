require 'spec_helper'

RSpec.describe EventQ::RabbitMq::QueueClient do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'rabbitmq' })
  end

  let(:connection) { client.get_connection }

  let(:channel) { connection.create_channel }

  it 'should use dead-letter exchange' do

    manager = EventQ::RabbitMq::QueueManager.new

    x    = channel.fanout("amq.fanout")
    dlx  = channel.fanout("bunny.examples.dlx.exchange")
    q    = channel.queue("subscriber", :durable => true, :arguments => {"x-dead-letter-exchange" => dlx.name}).bind(x, :routing_key => 'post')
# dead letter queue
    dlq  = channel.queue("subscriber_retry", :exclusive => true).bind(dlx)

    x.publish("", :routing_key => 'post')
    sleep 0.2

    delivery_tag, payload = manager.pop_message(queue: q)
    EventQ.logger.debug { "#{dlq.message_count} messages dead lettered so far" }
    expect(dlq.message_count).to eq(0)

    EventQ.logger.debug { "Rejecting a message" }
    channel.nack(delivery_tag)

    sleep 0.2

    channel = connection.create_channel
    dlx  = channel.fanout("bunny.examples.dlx.exchange")
    dlq  = channel.queue("subscriber_retry", :exclusive => true).bind(dlx)
    EventQ.logger.debug { "#{dlq.message_count} messages dead lettered so far" }
    expect(dlq.message_count).to eq(1)

    dlx.delete
    EventQ.logger.debug { "Disconnecting..." }
  end

  it 'should use a delay queue correctly' do

    retry_exchange = channel.fanout(SecureRandom.uuid)
    subscriber_exchange = channel.fanout(SecureRandom.uuid)

    retry_queue_def = EventQ::Queue.new
    retry_queue_def.name = SecureRandom.uuid

    queue_manager = EventQ::RabbitMq::QueueManager.new

    retry_queue = channel.queue(retry_queue_def.name, :arguments => { "x-dead-letter-exchange" => subscriber_exchange.name, "x-message-ttl" => 600 }).bind(retry_exchange)

    subscriber_queue_name = SecureRandom.uuid
    subscriber_queue = channel.queue(subscriber_queue_name).bind(subscriber_exchange)

    message = 'Hello World'

    retry_exchange.publish(message)

    delivery_tag, payload = queue_manager.pop_message(queue: retry_queue)

    expect(payload).to eq(message)

    retry_queue.purge

    retry_exchange.publish(message)

    channel = connection.create_channel
    subscriber_queue = channel.queue(subscriber_queue_name).bind(subscriber_exchange)

    sleep(1)

    delivery_tag, payload = queue_manager.pop_message(queue: subscriber_queue)

    expect(payload).to eq(message)
    channel.acknowledge(delivery_tag, false)

  end

  it 'should expire message from retry queue back into subscriber queue' do

    q = EventQ::Queue.new
    q.name = 'retry.test.queue'
    q.allow_retry = true
    q.retry_delay = 500

    qm = EventQ::RabbitMq::QueueManager.new

    queue = qm.get_queue(channel, q)
    retry_queue = qm.get_retry_queue(channel, q)

    retry_exchange = qm.get_retry_exchange(channel, queue)

    message = 'Hello World'

    retry_exchange.publish(message)

    sleep(2)

    delivery_tag, payload = qm.pop_message(queue: queue)
    expect(payload).to eq(message)
    channel.acknowledge(delivery_tag, false)

  end

  it 'should deliver a message from a queue' do
    manager = EventQ::RabbitMq::QueueManager.new
    queue = channel.queue(SecureRandom.uuid, :durable => true)
    exchange = channel.fanout(SecureRandom.uuid)
    queue.bind(exchange)

    exchange.publish('Hello World')
    sleep 0.5

    delivery_tag, payload = manager.pop_message(queue: queue)

    expect(payload).to eq 'Hello World'
  end

  after do
    channel.close if channel.open?
    connection.close
  end

end
