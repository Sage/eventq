require 'spec_helper'

RSpec.describe EventQ::RabbitMq::EventQClient do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'localhost' })
  end

  let(:subscription_manager) { EventQ::RabbitMq::SubscriptionManager.new({ client: client }) }

  subject do
    return EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
  end

  it 'should raise an event object and be broadcast to a subscriber queue' do

    event_type = 'test_event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'test_queue1'

    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    subject.raise_event(event_type, message)

    channel = client.get_channel

    queue_manager = EventQ::RabbitMq::QueueManager.new

    queue = queue_manager.get_queue(channel, subscriber_queue)

    qm = nil

    puts '[QUEUE] waiting for message...'

    begin
      delivery_info, properties, payload = queue.pop
      qm = Oj.load(payload)
      puts "[QUEUE] - received message: #{message}"
    rescue TimeOut::Error
      puts 'Failed due to connection timeout.'
    end


    expect(qm).to_not be_nil
    expect(qm.content).to eq(message)

  end

  describe '#raise' do
    let(:message) { 'Hello World' }

    subject { described_class.new(client: client, subscription_manager: subscription_manager) }

    it 'adds the event to default queue' do
      event_type = 'test_event2'

      channel = client.get_channel
      queue_manager = EventQ::RabbitMq::QueueManager.new
      queue = queue_manager.get_queue(channel, EventQ::RabbitMq::DefaultQueue.new)

      subject.raise_event(event_type, message)

      qm = nil

      puts '[QUEUE] waiting for message...'

      begin
        delivery_info, properties, payload = queue.pop
        qm = Oj.load(payload)
        puts "[QUEUE] - received message: #{message}"
      rescue
        puts 'Failed due to connection timeout.'
      end


      expect(qm).to_not be_nil
      expect(qm.content).to eq(message)
    end

  end

end
