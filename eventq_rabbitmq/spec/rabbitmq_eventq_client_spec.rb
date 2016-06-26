require 'spec_helper'

RSpec.describe EventQ::RabbitMq::EventQClient do

  it 'should raise an event object and be broadcast to a subscriber queue' do

    event_type = 'test_event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'test_queue1'

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    subject.raise(event_type, message)

    client = EventQ::RabbitMq::QueueClient.new

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
    let(:subscription_manager) { EventQ::RabbitMq::SubscriptionManager.new }

    subject { described_class.new(subscription_manager: subscription_manager) }

    it 'adds the event to default queue' do
      event_type = 'test_event2'

      client = EventQ::RabbitMq::QueueClient.new

      channel = client.get_channel
      queue_manager = EventQ::RabbitMq::QueueManager.new
      queue = queue_manager.get_queue(channel, EventQ::RabbitMq::DefaultQueue.new)

      subject.raise(event_type, message)

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
