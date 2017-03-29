RSpec.describe EventQ::RabbitMq::EventQClient do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'rabbitmq' })
  end

  let(:subscription_manager) { EventQ::RabbitMq::SubscriptionManager.new({ client: client }) }

  let(:queue_manager) { EventQ::RabbitMq::QueueManager.new }

  let(:connection) { client.get_connection }

  let(:channel) { connection.create_channel }

  let(:event_type) { 'test_event1' }
  let(:message) { 'Hello World' }

  subject do
    EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
  end

  let(:subscriber_queue) do
    EventQ::Queue.new.tap do |sq|
      sq.name = SecureRandom.uuid
    end
  end

  describe '#raise_event' do

    shared_examples 'any event raising' do
      it 'should raise an event object and be broadcast to a subscriber queue' do
        subscription_manager.subscribe(event_type, subscriber_queue)

        subject.raise_event(event_type, message)

        queue = queue_manager.get_queue(channel, subscriber_queue)

        qm = nil

        puts '[QUEUE] waiting for message...'

        begin
          _delivery_info, _properties, payload = queue.pop
          qm = Oj.load(payload)
          puts "[QUEUE] - received message: #{qm&.content.inspect}"
        rescue TimeOut::Error
          puts 'Failed due to connection timeout.'
        end

        expect(qm).to_not be_nil
        expect(qm.content).to eq(message)
      end
    end


    context 'when EventQ.namespace is NOT specified' do
      it_behaves_like 'any event raising'
    end

    context 'when EventQ.namespace is specified' do
      before do
        EventQ.namespace = 'test'
      end

      it_behaves_like 'any event raising'

      after do
        EventQ.namespace = nil
      end
    end
  end

  describe '#raise_event_in_queue' do
    let(:queue_name) { 'How_do_I_learn_to_queue_like_a_British_person' }
    let(:queue_in) do
      EventQ::Queue.new.tap do |queue|
        queue.name = queue_name
      end
    end
    let(:delay_seconds) { 3 }

    it 'should raise an event object with a delay' do
      subscription_manager.subscribe(event_type, subscriber_queue)

      subject.raise_event_in_queue(event_type, message, queue_in, delay_seconds)

      queue = queue_manager.get_queue(channel, subscriber_queue)

      qm = nil

      puts '[QUEUE] waiting for message... (but there should be none)'

      begin
        _delivery_info, _properties, payload = queue.pop
        qm = Oj.load(payload.to_s)
        puts "[QUEUE] - received message: #{qm&.content.inspect}"
      rescue TimeOut::Error
        puts 'Failed due to connection timeout.'
      end

      expect(qm).to be_nil

      puts '[QUEUE] waiting for message...'
      sleep 3.2

      begin
        _delivery_info, _properties, payload = queue.pop
        qm = Oj.load(payload.to_s)
        puts "[QUEUE] - received message: #{qm&.content.inspect}"
      rescue TimeOut::Error
        puts 'Failed due to connection timeout.'
      end

      expect(qm).to_not be_nil
      expect(qm.content).to eq(message)
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
