require 'spec_helper'

RSpec.describe RabbitMqEventQClient do

  it 'should raise an event object and be broadcast to a subscriber queue' do

    event_type = 'test_event1'
    subscriber_queue = Queue.new
    subscriber_queue.name = 'test_queue1'

    client = RabbitMqQueueClient.new

    subscription_manager = RabbitMqSubscriptionManager.new
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    subject.raise(event_type, message)

    channel = client.get_channel

    queue_manager = RabbitMqQueueManager.new

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
    let(:subscription_manager) { RabbitMqSubscriptionManager.new }

    subject { described_class.new(subscription_manager: subscription_manager) }

    it 'adds the event to default queue' do
      event_type = 'test_event2'

      client = RabbitMqQueueClient.new

      subject.raise(event_type, message)
      channel = client.get_channel
      queue_manager = RabbitMqQueueManager.new
      queue = queue_manager.get_queue(channel, DefaultQueue.new)

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

  end

end
