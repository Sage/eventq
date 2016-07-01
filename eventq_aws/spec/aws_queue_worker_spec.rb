require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueWorker do

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new({ aws_account_number: 997524026223 })
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

    sleep(2)

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

end