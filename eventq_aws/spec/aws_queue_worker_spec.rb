require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueWorker do

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new({ aws_account_number: '', aws_region: 'eu-west-1' })
  end

  let(:queue_manager) do
    EventQ::Amazon::QueueManager.new({ client: queue_client })
  end

  let(:subscription_manager) do
    EventQ::Amazon::SubscriptionManager.new({ client: queue_client, queue_manager: queue_manager })
  end

  let(:eventq_client) do
    EventQ::Amazon::EventQClient.new({ client: queue_client })
  end

  it 'should receive an event from the subscriber queue' do

    event_type = 'queue_worker_event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = SecureRandom.uuid.to_s

    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eventq_client.raise_event(event_type, message)

    received = false

    #wait 1 second to allow the message to be sent and broadcast to the queue
    sleep(1)

    subject.start(subscriber_queue, {:sleep => 1, :thread_count => 1, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)
      received = true
      puts "Message Received: #{event}"
    end

    sleep(5)

    subject.stop

    expect(received).to eq(true)

    expect(subject.is_running).to eq(false)

  end

  it 'should receive an event from the subscriber queue and retry it.' do

    event_type = 'queue_worker_event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = SecureRandom.uuid.to_s
    subscriber_queue.retry_delay = 1000
    subscriber_queue.allow_retry = true

    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eventq_client.raise_event(event_type, message)

    received = false
    received_count = 0
    received_attribute = 0;

    #wait 1 second to allow the message to be sent and broadcast to the queue
    sleep(1)

    subject.start(subscriber_queue, {:sleep => 1, :thread_count => 1, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)
      received = true
      received_count += 1
      received_attribute = args.retry_attempts
      puts "Message Received: #{event}"
      if received_count != 2
        args.abort = true
      end
    end

    sleep(10)

    subject.stop

    expect(received).to eq(true)
    expect(received_count).to eq(2)
    expect(received_attribute).to eq(1)
    expect(subject.is_running).to eq(false)

  end

  it 'should receive events in parallel on each thread from the subscriber queue' do

    event_type = 'queue_worker_event2'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = SecureRandom.uuid.to_s

    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)
    eventq_client.raise_event(event_type, message)

    received_messages = []

    message_count = 0

    mutex = Mutex.new

    subject.start(subscriber_queue, {:sleep => 0.5, :thread_count => 5, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)

      mutex.synchronize do
        puts "Message Received: #{event}"
        message_count += 1
        add_to_received_list(received_messages)
        puts 'message processed.'
      end
    end

    sleep(3)

    expect(message_count).to eq(10)
    expect(received_messages.length).to eq(5)
    expect(received_messages[0][:events]).to be >= 1
    expect(received_messages[1][:events]).to be >= 1
    expect(received_messages[2][:events]).to be >= 1
    expect(received_messages[3][:events]).to be >= 1
    expect(received_messages[4][:events]).to be >= 1

    subject.stop

    expect(subject.is_running).to eq(false)

  end

  context 'queue.allow_retry_back_off = true' do
    it 'should receive an event from the subscriber queue and retry it.' do

      event_type = 'queue_worker_event1'
      subscriber_queue = EventQ::Queue.new
      subscriber_queue.name = SecureRandom.uuid.to_s
      subscriber_queue.retry_delay = 1000
      subscriber_queue.allow_retry = true
      subscriber_queue.allow_retry_back_off = true
      subscriber_queue.max_retry_delay = 5000

      subscription_manager.subscribe(event_type, subscriber_queue)

      message = 'Hello World'

      eventq_client.raise_event(event_type, message)

      retry_attempt_count = 0

      #wait 1 second to allow the message to be sent and broadcast to the queue
      sleep(1)

      subject.start(subscriber_queue, {:sleep => 1, :thread_count => 1, client: queue_client }) do |event, args|
        expect(event).to eq(message)
        expect(args).to be_a(EventQ::MessageArgs)
        retry_attempt_count = args.retry_attempts + 1
        raise 'Fail on purpose to send event to retry queue.'
      end

      sleep(1.1)

      expect(retry_attempt_count).to eq(1)

      sleep(2.1)

      expect(retry_attempt_count).to eq(2)

      sleep(3.1)

      expect(retry_attempt_count).to eq(3)

      sleep(4.1)

      expect(retry_attempt_count).to eq(4)

      subject.stop

      expect(subject.is_running).to eq(false)

    end
  end

  def add_to_received_list(received_messages)

    thread_name = Thread.current.object_id
    puts "[THREAD] #{thread_name}"
    thread = received_messages.detect { |i| i[:thread] == thread_name }

    if thread != nil
      thread[:events] += 1
    else
      received_messages.push({ :events => 1, :thread => thread_name })
    end

  end

  describe '#deserialize_message' do
    context 'when serialization provider is OJ_PROVIDER' do
      before do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
      context 'when payload is for a known type' do
        let(:a) do
          A.new.tap do |a|
            a.text = 'ABC'
          end
        end
        let(:payload) { Oj.dump(a) }
        it 'should deserialize the message into an object of the known type' do
          message = subject.deserialize_message(payload)
          expect(message).to be_a(A)
          expect(message.text).to eq('ABC')
        end
      end
      context 'when payload is for an unknown type' do
        let(:a) do
          A.new.tap do |a|
            a.text = 'ABC'
          end
        end
        let(:payload) do
          string = Oj.dump(a)
          JSON.load(string.sub('"^o":"A"', '"^o":"B"'))
        end
        let(:message) do
          EventQ::QueueMessage.new.tap do |m|
            m.content = payload
          end
        end
        let(:json) do
          Oj.dump(message)
        end
        it 'should deserialize the message into a Hash' do
          message = subject.deserialize_message(json)
          expect(message.content).to be_a(Hash)
          expect(message.content[:text]).to eq('ABC')
        end
      end
    end
    context 'when serialization provider is JSON_PROVIDER' do
      before do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::JSON_PROVIDER
      end
      let(:payload) do
        {
            content: { text: 'ABC' }
        }
      end
      let(:json) do
        JSON.dump(payload)
      end
      it 'should deserialize payload' do
        message = subject.deserialize_message(json)
        expect(message).to be_a(EventQ::QueueMessage)
        expect(message.content).to be_a(Hash)
        expect(message.content[:text]).to eq('ABC')
      end
      after do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
    end
  end

end

class A
  attr_accessor :text
end
