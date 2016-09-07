require 'spec_helper'

RSpec.describe EventQ::RabbitMq::QueueWorker do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'rabbitmq' })
  end

  it 'should receive an event from the subscriber queue' do

    event_type = 'queue.worker.event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'queue.worker1'

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({ client: client})
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
    eqclient.raise_event(event_type, message)

    received = false

    subject.start(subscriber_queue, {:sleep => 1, client: client}) do |event, args|
      expect(event).to eq(message)
      expect(args.type).to eq(event_type)
      received = true
      puts "Message Received: #{event}"
    end

    sleep(0.5)

    expect(received).to eq(true)

    subject.stop

    expect(subject.is_running).to eq(false)

  end

  it 'should receive events in parallel on each thread from the subscriber queue' do

    event_type = 'queue.worker.event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'queue.worker1'

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({client: client})
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)
    eqclient.raise_event(event_type, message)

    received_messages = []

    message_count = 0

    mutex = Mutex.new

    subject.start(subscriber_queue, {:sleep => 0.5, :thread_count => 5, client: client}) do |event, args|
      expect(event).to eq(message)
      expect(args.type).to eq(event_type)

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
    expect(received_messages[0][:events]).to eq(2)
    expect(received_messages[1][:events]).to eq(2)
    expect(received_messages[2][:events]).to eq(2)
    expect(received_messages[3][:events]).to eq(2)
    expect(received_messages[4][:events]).to eq(2)

    subject.stop

    expect(subject.is_running).to eq(false)

  end

  def add_to_received_list(received_messages)

    thread_name = Thread.current.object_id
    puts "[THREAD] #{thread_name}"
    thread = received_messages.select { |i| i[:thread] == thread_name }

    if thread.length > 0
      thread[0][:events] += 1
    else
      received_messages.push({ :events => 1, :thread => thread_name })
    end

  end

  it 'should send messages that fail to process to the retry queue and then receive them again after the retry delay' do

    event_type = 'queue.worker.event2'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'queue.worker2'
    #set queue retry delay to 0.5 seconds
    subscriber_queue.retry_delay = 500
    subscriber_queue.allow_retry = true

    qm = EventQ::RabbitMq::QueueManager.new
    q = qm.get_queue(client.get_channel, subscriber_queue)
    q.delete

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({client: client})
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
    eqclient.raise_event(event_type, message)

    retry_attempt_count = 0

    subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5, client: client}) do |event, args|

      if args.retry_attempts == 0
        raise 'Fail on purpose to send event to retry queue.'
      end

      retry_attempt_count = args.retry_attempts

    end

    sleep(5)

    expect(retry_attempt_count).to eq(1)

    subject.stop

    expect(subject.is_running).to eq(false)

  end

  context 'queue.allow_retry_back_off = true' do
    it 'should send messages that fail to process to the retry queue and then receive them again after the retry delay' do

      event_type = 'queue.worker.event5'
      subscriber_queue = EventQ::Queue.new
      subscriber_queue.name = 'queue.worker5'
      #set queue retry delay to 0.5 seconds
      subscriber_queue.retry_delay = 500
      subscriber_queue.allow_retry = true
      subscriber_queue.allow_retry_back_off = true
      #set to max retry delay to 5 seconds
      subscriber_queue.max_retry_delay = 5000

      qm = EventQ::RabbitMq::QueueManager.new
      q = qm.get_queue(client.get_channel, subscriber_queue)
      q.delete

      subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({client: client})
      subscription_manager.subscribe(event_type, subscriber_queue)

      message = 'Hello World'

      eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
      eqclient.raise_event(event_type, message)

      retry_attempt_count = 0

      subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5, client: client}) do |event, args|

        retry_attempt_count = args.retry_attempts
        raise 'Fail on purpose to send event to retry queue.'

      end

      sleep(0.6)

      expect(retry_attempt_count).to eq(1)

      sleep(1.1)

      expect(retry_attempt_count).to eq(2)

      sleep(1.6)

      expect(retry_attempt_count).to eq(3)

      sleep(2.1)

      expect(retry_attempt_count).to eq(4)

      subject.stop

      expect(subject.is_running).to eq(false)

    end
  end

  it 'should execute the #on_retry_exceeded block when a message exceeds its retry limit' do

    event_type = 'queue.worker.event3'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'queue.worker3'
    #set queue retry delay to 0.5 seconds
    subscriber_queue.retry_delay = 500
    subscriber_queue.allow_retry = true
    subscriber_queue.max_retry_attempts = 1

    qm = EventQ::RabbitMq::QueueManager.new
    q = qm.get_queue(client.get_channel, subscriber_queue)
    q.delete

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({client: client})
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
    eqclient.raise_event(event_type, message)

    retry_attempt_count = 0

    failed_message = nil

    subject.on_retry_exceeded do |message|
      failed_message = message
    end

    subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5, client: client }) do |event, args|

      retry_attempt_count = args.retry_attempts
      raise 'Fail on purpose to send event to retry queue.'

    end

    sleep(5)

    expect(retry_attempt_count).to eq(1)
    expect(failed_message.content).to eq(message)
    expect(failed_message.retry_attempts).to eq(1)
    expect(failed_message.type).to eq(event_type)

    subject.stop

    expect(subject.is_running).to eq(false)

  end

  it 'should not retry an event when it fails for a queue that does not allow retries' do

    event_type = 'queue.worker.event4'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'queue.worker4'
    subscriber_queue.allow_retry = false

    qm = EventQ::RabbitMq::QueueManager.new
    q = qm.get_queue(client.get_channel, subscriber_queue)
    q.delete

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({client: client})
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})
    eqclient.raise_event(event_type, message)

    retry_attempt_count = 0

    failed_message = nil

    subject.on_retry_exceeded do |message|
      failed_message = message
    end

    subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5, client: client }) do |event, args|

      retry_attempt_count = args.retry_attempts
      raise 'Fail on purpose to send event to retry queue.'

    end

    sleep(5)

    expect(retry_attempt_count).to eq(0)
    expect(failed_message).to be_nil

    subject.stop

    expect(subject.is_running).to eq(false)

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