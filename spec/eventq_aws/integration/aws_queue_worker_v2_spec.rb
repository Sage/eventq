require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueWorker, integration: true do
include_context 'mock_aws_visibility_timeout'
include_context 'aws_wait_for_message_processed_helper'

  let(:queue_worker) { EventQ::QueueWorker.new }

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new
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
  let(:message_context) { { 'foo' => 'bar' } }

  it 'should receive an event from the subscriber queue' do
    subscription_manager.subscribe(event_type, subscriber_queue)
    eventq_client.raise_event(event_type, message, message_context)

    received = false
    context = nil

    queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)
      context = message_context
      received = true
      EventQ.logger.debug {  "Message Received: #{event}" }
    end

    wait_for_message_processed

    expect(received).to eq(true)
    expect(context).to eq message_context

    queue_worker.stop
    expect(queue_worker.running?).to eq(false)
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

        queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
          expect(event).to eq(message)
          expect(args).to be_a(EventQ::MessageArgs)
          received = true
          EventQ.logger.debug {  "Message Received: #{event}" }
        end

        wait_for_message_processed

        expect(received).to eq(true)

        queue_worker.stop
        expect(queue_worker.running?).to eq(false)
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

        queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
          expect(event).to eq(message)
          expect(args).to be_a(EventQ::MessageArgs)
          received = true
          EventQ.logger.debug {  "Message Received: #{event}" }
        end

        wait_for_message_processed

        expect(received).to eq(true)

        queue_worker.stop
        expect(queue_worker.running?).to eq(false)
      end
    end
  end

  it 'should receive an event from the subscriber queue and retry it (abort).' do
    subscriber_queue.retry_delay = 1000
    subscriber_queue.allow_retry = true

    subscription_manager.subscribe(event_type, subscriber_queue)
    eventq_client.raise_event(event_type, message)

    received = false
    received_count = 0
    received_attribute = 0

    queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)
      received = true
      received_count += 1
      received_attribute = args.retry_attempts
      EventQ.logger.debug {  "Message Received: #{event}" }
      if received_count != 2
        args.abort = true
      end
    end

    2.times { wait_for_message_processed }

    expect(received).to eq(true)
    expect(received_count).to eq(2)
    expect(received_attribute).to eq(1)

    queue_worker.stop
    expect(queue_worker.running?).to eq(false)
  end

  it 'should receive an event from the subscriber queue and retry it (error).' do

    subscriber_queue.retry_delay = 1000
    subscriber_queue.allow_retry = true

    subscription_manager.subscribe(event_type, subscriber_queue)
    eventq_client.raise_event(event_type, message)

    received = false
    received_count = 0
    received_attribute = 0;

    queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)
      received = true
      received_count += 1
      received_attribute = args.retry_attempts
      EventQ.logger.debug {  "Message Received: #{event}" }
      if received_count != 2
        raise 'fake error'
      end
    end

    2.times { wait_for_message_processed }

    expect(received).to eq(true)
    expect(received_count).to eq(2)
    expect(received_attribute).to eq(1)

    queue_worker.stop
    expect(queue_worker.running?).to eq(false)
  end

  it 'should receive multiple events from the subscriber queue' do

    subscription_manager.subscribe(event_type2, subscriber_queue)

    10.times do
      eventq_client.raise_event(event_type2, message)
    end

    received_messages = []

    message_count = 0

    mutex = Mutex.new

    queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
      expect(event).to eq(message)
      expect(args).to be_a(EventQ::MessageArgs)

      mutex.synchronize do
        EventQ.logger.debug {  "Message Received: #{event}" }
        message_count += 1
        add_to_received_list(received_messages)
        EventQ.logger.debug {  'message processed.' }
      end
    end

    10.times { wait_for_message_processed }

    expect(message_count).to eq(10)

    queue_worker.stop
    expect(queue_worker.running?).to eq(false)
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

      queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
        expect(event).to eq(message)
        expect(args).to be_a(EventQ::MessageArgs)
        raise 'Fail on purpose to send event to retry queue.'
      end

      expect(aws_visibility_timeout_queue.pop).to eq(call: 1, visibility_timeout: 1)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 2, visibility_timeout: 2)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 3, visibility_timeout: 3)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 4, visibility_timeout: 4)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 5, visibility_timeout: 5)

      queue_worker.stop
      expect(queue_worker.running?).to eq(false)
    end
  end

  context 'queue.allow_retry_back_off = true && queue.retry_back_off_grace = 4' do
    before do
      subscriber_queue.retry_delay = 1000
      subscriber_queue.allow_retry = true
      subscriber_queue.allow_retry_back_off = true
      subscriber_queue.max_retry_delay = 5000
      subscriber_queue.retry_back_off_grace = 4
      subscriber_queue.max_retry_attempts = 10
    end

    it 'should receive an event from the subscriber queue and retry it.' do

      subscription_manager.subscribe(event_type, subscriber_queue)
      eventq_client.raise_event(event_type, message)

      queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
        expect(event).to eq(message)
        expect(args).to be_a(EventQ::MessageArgs)
        raise 'Fail on purpose to send event to retry queue.'
      end

      expect(aws_visibility_timeout_queue.pop).to eq(call: 1, visibility_timeout: 1)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 2, visibility_timeout: 1)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 3, visibility_timeout: 1)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 4, visibility_timeout: 1)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 5, visibility_timeout: 1)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 6, visibility_timeout: 2)
      expect(aws_visibility_timeout_queue.pop).to eq(call: 7, visibility_timeout: 3)

      queue_worker.stop
      expect(queue_worker.running?).to eq(false)
    end
  end

  def add_to_received_list(received_messages)

    thread_name = Thread.current.object_id
    EventQ.logger.debug {  "[THREAD] #{thread_name}" }
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
        EventQ::NonceManager.configure(server: ENV.fetch('REDIS_ENDPOINT', 'redis://redis:6379'))
      end
      let(:queue_message) { EventQ::QueueMessage.new }
      let(:event_type) { "queue_worker_event_noncemanager_#{SecureRandom.hex(2)}" }

      it 'should NOT process the message again' do
        subscription_manager.subscribe(event_type, subscriber_queue)
        allow(eventq_client).to receive(:new_message).and_return(queue_message)

        eventq_client.raise_event(event_type, message)
        eventq_client.raise_event(event_type, message)

        received_count = 0

        # wait 1 second to allow the message to be sent and broadcast to the queue
        sleep(1)

        queue_worker.start(subscriber_queue, { worker_adapter: subject, wait: false, block_process: false, client: queue_client }) do |event, args|
          received_count += 1
        end

        sleep(2.5)

        queue_worker.stop

        expect(received_count).to eq 1

      end

      after do
        EventQ::NonceManager.reset
      end
    end
  end
end
