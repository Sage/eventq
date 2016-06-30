require 'spec_helper'

RSpec.describe EventQ::RabbitMq::QueueWorker do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new
  end

  it 'should receive an event from the subscriber queue' do

    event_type = 'queue.worker.event1'
    subscriber_queue = EventQ::Queue.new
    subscriber_queue.name = 'queue.worker1'

    subscription_manager = EventQ::RabbitMq::SubscriptionManager.new
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client})
    eqclient.raise_event(event_type, message)

    received = false

    subject.start(subscriber_queue, {:sleep => 1}) do |event, args|
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

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client})
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

    subject.start(subscriber_queue, {:sleep => 0.5, :thread_count => 5}) do |event, args|
      expect(event).to eq(message)
      expect(args.type).to eq(event_type)

      mutex.synchronize do
        puts "Message Received: #{event}"
        message_count += 1
        add_to_received_list(received_messages)
        puts 'message processed.'
      end
    end

    sleep(2)

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

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client})
    eqclient.raise_event(event_type, message)

    retry_attempt_count = 0

    subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5 }) do |event, args|

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

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client})
    eqclient.raise_event(event_type, message)

    retry_attempt_count = 0

    failed_message = nil

    subject.on_retry_exceeded do |message|
      failed_message = message
    end

    subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5 }) do |event, args|

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

    eqclient = EventQ::RabbitMq::EventQClient.new({client: client})
    eqclient.raise_event(event_type, message)

    retry_attempt_count = 0

    failed_message = nil

    subject.on_retry_exceeded do |message|
      failed_message = message
    end

    subject.start(subscriber_queue, { :thread_count => 1, :sleep => 0.5 }) do |event, args|

      retry_attempt_count = args.retry_attempts
      raise 'Fail on purpose to send event to retry queue.'

    end

    sleep(5)

    expect(retry_attempt_count).to eq(0)
    expect(failed_message).to be_nil

    subject.stop

    expect(subject.is_running).to eq(false)

  end

end