RSpec.describe EventQ::RabbitMq::EventQClient do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'rabbitmq' })
  end

  let(:subscription_manager) { EventQ::RabbitMq::SubscriptionManager.new({ client: client }) }

  subject do
    return EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
  end

  let(:connection) { client.get_connection }

  let(:channel) { connection.create_channel }

  context 'when EventQ.namespace is NOT specified' do
    it 'should raise an event object and be broadcast to a subscriber queue' do

      event_type = 'test_event1'
      subscriber_queue = EventQ::Queue.new
      subscriber_queue.name = SecureRandom.uuid

      subscription_manager.subscribe(event_type, subscriber_queue)

      message = 'Hello World'

      subject.raise_event(event_type, message)

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
  end

  context 'when EventQ.namespace is specified' do

    before do
      EventQ.namespace = 'test'
    end

    it 'should raise an event object and be broadcast to a subscriber queue' do

      event_type = 'test_event1'
      subscriber_queue = EventQ::Queue.new
      subscriber_queue.name = SecureRandom.uuid

      subscription_manager.subscribe(event_type, subscriber_queue)

      message = 'Hello World'

      subject.raise_event(event_type, message)

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

    after do
      EventQ.namespace = nil
    end
  end

  describe '#register_event' do
    let(:event_type) { 'event_type' }
    context 'when an event is NOT already registered' do
      it 'should register the event and return true' do
        expect(subject.register_event(event_type)).to be true
        known_types = subject.instance_variable_get(:@known_event_types)
        expect(known_types.include?(event_type)).to be true
      end
    end
    context 'when an event has already been registered' do
      before do
        known_types = subject.instance_variable_get(:@known_event_types)
        known_types << event_type
      end
      it 'should return true' do
        expect(subject.register_event(event_type)).to be true
      end
    end
  end

  describe '#registered?' do
    let(:event_type) { 'event_type' }
    context 'when an event_type is registered' do
      before do
        known_types = subject.instance_variable_get(:@known_event_types)
        known_types << event_type
      end
      it 'should return true' do
        expect(subject.registered?(event_type)).to be true
      end
    end
    context 'when an event_type is NOT registered' do
      it 'should return false' do
        expect(subject.registered?(event_type)).to be false
      end
    end
  end

  after do
    channel.close
    connection.close
  end

end
