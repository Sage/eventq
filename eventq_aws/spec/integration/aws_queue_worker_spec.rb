require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueWorker, integration: true do

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new({ aws_account_number: EventQ.AWS_ACCOUNT_NUMBER, aws_region: 'eu-west-1' })
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

  let(:subscriber_queue) do
    EventQ::Queue.new.tap do |sq|
      sq.name = SecureRandom.uuid.to_s
    end
  end

  let(:event_type) { 'queue_worker_event1' }
  let(:event_type2) { 'queue_worker_event2' }
  let(:message) { 'Hello World' }

  it 'should receive an event from the subscriber queue' do
    subscription_manager.subscribe(event_type, subscriber_queue)
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

    sleep(2)

    subject.stop

    expect(received).to eq(true)

    expect(subject.is_running).to eq(false)
  end

  context 'when queue requires a signature' do
    let(:secret) { 'secret' }

    before do
      EventQ::Configuration.signature_secret = secret
      subscriber_queue.require_signature = true
    end

    context 'and the received message contains a valid signature' do
      it 'should process the message' do
        subscription_manager.subscribe(event_type, subscriber_queue)
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

        sleep(2)

        subject.stop

        expect(received).to eq(true)

        expect(subject.is_running).to eq(false)
      end
    end

    context 'and the received message contains an invalid signature' do
      before do
        EventQ::Configuration.signature_secret = 'invalid'
      end

      it 'should NOT process the message' do
        subscription_manager.subscribe(event_type, subscriber_queue)
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

        sleep(2)

        subject.stop

        expect(received).to eq(true)

        expect(subject.is_running).to eq(false)
      end
    end
  end

  it 'should receive an event from the subscriber queue and retry it.' do

    subscriber_queue.retry_delay = 1000
    subscriber_queue.allow_retry = true

    subscription_manager.subscribe(event_type, subscriber_queue)
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

    sleep(4)

    subject.stop

    expect(received).to eq(true)
    expect(received_count).to eq(2)
    expect(received_attribute).to eq(1)
    expect(subject.is_running).to eq(false)
  end

  it 'should receive events in parallel on each thread from the subscriber queue' do

    subscription_manager.subscribe(event_type2, subscriber_queue)

    10.times do
      eventq_client.raise_event(event_type2, message)
    end

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

    sleep(5)

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
    before do
      subscriber_queue.retry_delay = 1000
      subscriber_queue.allow_retry = true
      subscriber_queue.allow_retry_back_off = true
      subscriber_queue.max_retry_delay = 5000
    end

    it 'should receive an event from the subscriber queue and retry it.' do

      subscription_manager.subscribe(event_type, subscriber_queue)
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

      sleep(1)

      expect(retry_attempt_count).to eq(1)

      sleep(2)

      expect(retry_attempt_count).to eq(2)

      sleep(3)

      expect(retry_attempt_count).to eq(3)

      sleep(4)

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

  context 'NonceManager' do
    context 'when a message has already been processed' do
      before do
        EventQ::NonceManager.configure(server: 'redis://redis:6379')
      end
      let(:queue_message) { EventQ::QueueMessage.new }
      let(:event_type) { 'queue_worker_event_noncemanager' }

      it 'should NOT process the message again' do
        subscription_manager.subscribe(event_type, subscriber_queue)
        allow(eventq_client).to receive(:new_message).and_return(queue_message)

        eventq_client.raise_event(event_type, message)
        eventq_client.raise_event(event_type, message)

        received_count = 0

        #wait 1 second to allow the message to be sent and broadcast to the queue
        sleep(1)

        subject.start(subscriber_queue, {:sleep => 1, :thread_count => 1, client: queue_client }) do |event, args|
          received_count += 1
        end

        sleep(2.5)

        subject.stop

        expect(received_count).to eq 1

      end

      after do
        EventQ::NonceManager.reset
      end
    end
  end
end
