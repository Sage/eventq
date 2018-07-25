require 'spec_helper'

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
  let(:message_context) { { 'foo' => 'bar' } }

  let(:class_kit) { ClassKit::Helper.new }

  subject do
    EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
  end

  let(:subscriber_queue) do
    EventQ::Queue.new.tap do |sq|
      sq.name = SecureRandom.uuid
    end
  end

  def receive_message(queue)
    delivery_tag, payload = queue_manager.pop_message(queue: queue)
    if payload == nil
      return nil
    end

    qm = Oj.load(payload.to_s)
    if qm == nil
      return nil
    end

    EventQ.logger.debug { "[QUEUE] - received message: #{qm.content}" }
    qm
  end

  describe '#publish' do
    it 'should raise an event object and be broadcast to a subscriber queue' do
      subscription_manager.subscribe(event_type, subscriber_queue)

      subject.publish(topic: event_type, event: message, context: message_context)

      queue = queue_manager.get_queue(channel, subscriber_queue)

      EventQ.logger.debug { '[QUEUE] waiting for message...' }

      qm = receive_message(queue)

      expect(qm).to_not be_nil
      expect(qm.content).to eq(message)
      expect(qm.content_type).to eq message.class.to_s
      expect(qm.context).to eq message_context
    end
  end

  describe '#raise_event' do

    shared_examples 'any event raising' do
      it 'should raise an event object and be broadcast to a subscriber queue' do
        subscription_manager.subscribe(event_type, subscriber_queue)

        subject.raise_event(event_type, message, message_context)

        queue = queue_manager.get_queue(channel, subscriber_queue)

        EventQ.logger.debug { '[QUEUE] waiting for message...' }

        qm = receive_message(queue)

        expect(qm).to_not be_nil
        expect(qm.content).to eq(message)
        expect(qm.content_type).to eq message.class.to_s
        expect(qm.context).to eq message_context
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
    let(:queue_name) { SecureRandom.uuid }
    let(:queue_in) do
      EventQ::Queue.new.tap do |queue|
        queue.name = queue_name
      end
    end
    let(:delay_seconds) { 2 }

    it 'should raise an event object with a delay' do
      subject.raise_event_in_queue(event_type, message, queue_in, delay_seconds)

      queue = channel.queue(queue_name, durable: queue_manager.durable)

      EventQ.logger.debug { '[QUEUE] waiting for message... (but there should be none yet)' }

      qm = receive_message(queue)
      expect(qm).to be_nil

      EventQ.logger.debug { '[QUEUE] waiting for message...' }
      sleep 2.5

      qm = receive_message(queue)
      expect(qm).to_not be_nil
      expect(qm.content).to eq(message)
    end

    context 'two events with different delays' do
      let(:other_delay_seconds) { 4 }
      let(:other_message) { 'Brave New World' }

      it 'should raise an event object with a delay' do
        subject.raise_event_in_queue(event_type, message, queue_in, delay_seconds)
        subject.raise_event_in_queue(event_type, other_message, queue_in, other_delay_seconds)

        queue = channel.queue(queue_name, durable: queue_manager.durable)

        EventQ.logger.debug { '[QUEUE] waiting for message... (but there should be none yet)' }

        qm = receive_message(queue)
        expect(qm).to be_nil

        EventQ.logger.debug { '[QUEUE] waiting for message...' }
        sleep 2.2

        qm = receive_message(queue)
        expect(qm).to_not be_nil
        expect(qm.content).to eq(message)

        # check for other message

        EventQ.logger.debug { '[QUEUE] waiting for other message... (but there should be none yet)' }

        qm = receive_message(queue)
        expect(qm).to be_nil

        EventQ.logger.debug { '[QUEUE] waiting for other message...' }
        sleep 2

        qm = receive_message(queue)
        expect(qm).to_not be_nil
        expect(qm.content).to eq(other_message)
      end
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
    channel.close if channel.open?
    connection.close
  end
end
