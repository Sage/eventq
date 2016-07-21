require 'spec_helper'

RSpec.describe EventQ::RabbitMq::QueueClient do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'localhost' })
  end

  it 'should use dead-letter exchange' do

    ch   = client.get_channel
    x    = ch.fanout("amq.fanout")
    dlx  = ch.fanout("bunny.examples.dlx.exchange")
    q    = ch.queue("subscriber", :durable => true, :arguments => {"x-dead-letter-exchange" => dlx.name}).bind(x, :routing_key => 'post')
# dead letter queue
    dlq  = ch.queue("subscriber_retry", :exclusive => true).bind(dlx)

    x.publish("", :routing_key => 'post')
    sleep 0.2

    delivery_info, _, _ = q.pop(:manual_ack => true)
    puts "#{dlq.message_count} messages dead lettered so far"
    expect(dlq.message_count).to eq(0)

    puts "Rejecting a message"
    ch.nack(delivery_info.delivery_tag, false)
    sleep 0.2
    puts "#{dlq.message_count} messages dead lettered so far"
    expect(dlq.message_count).to eq(1)

    dlx.delete
    puts "Disconnecting..."
  end

  it 'should use a delay queue correctly' do

    channel = client.get_channel

    retry_exchange = channel.fanout('retry.exchange')
    subscriber_exchange = channel.fanout('subscriber.exchange')

    retry_queue_def = EventQ::Queue.new
    retry_queue_def.name = 'retry.queue'

    queue_manager = EventQ::RabbitMq::QueueManager.new

    retry_queue = channel.queue(retry_queue_def.name, :arguments => { "x-dead-letter-exchange" => subscriber_exchange.name, "x-message-ttl" => 600 }).bind(retry_exchange)

    subscriber_queue = channel.queue('subscriber.queue').bind(subscriber_exchange)

    message = 'Hello World'

    retry_exchange.publish(message)

    delivery_info, properties, payload = retry_queue.pop(:manual_ack => true)

    expect(payload).to eq(message)

    channel.close
    channel = client.get_channel
    subscriber_queue = channel.queue('subscriber.queue')

    sleep(1)

    delivery_info, properties, payload = subscriber_queue.pop(:manual_ack => true)
    expect(payload).to eq(message)
    channel.acknowledge(delivery_info.delivery_tag, false)

  end

  it 'should expire message from retry queue back into subscriber queue' do

    channel = client.get_channel

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

    delivery_info, properties, payload = queue.pop(:manual_ack => true)
    expect(payload).to eq(message)
    channel.acknowledge(delivery_info.delivery_tag, false)

  end

end
