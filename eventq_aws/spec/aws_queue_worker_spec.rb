require 'spec_helper'

RSpec.describe EventQ::Aws::QueueWorker do

  it 'should receive an event from the subscriber queue' do

    event_type = 'queue_worker_event1'
    subscriber_queue = Queue.new
    subscriber_queue.name = 'queue_worker1'

    client = EventQ::Aws::QueueClient.new

    subscription_manager = EventQ::Aws::SubscriptionManager.new
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    client = EventQ::Aws::EventQClient.new

    client.raise_event(event_type, message)

    received = false

    #wait 1 second to allow the message to be sent and broadcast to the queue
    sleep(1)

    subject.start(subscriber_queue, {:sleep => 1, :thread_count => 1}) do |event, type|
      expect(event).to eq(message)
      expect(type).to eq(event_type)
      received = true
      puts "Message Received: #{event}"
    end

    sleep(1)

    expect(received).to eq(true)

    subject.stop

    expect(subject.is_running).to eq(false)

  end

  it 'should receive events in parallel on each thread from the subscriber queue' do

    event_type = 'queue_worker_event2'
    subscriber_queue = Queue.new
    subscriber_queue.name = 'queue_worker2'

    client = EventQ::Aws::QueueClient.new

    subscription_manager = EventQ::Aws::SubscriptionManager.new
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    client = EventQ::Aws::EventQClient.new
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)
    client.raise_event(event_type, message)

    received_messages = []

    message_count = 0

    mutex = Mutex.new

    subject.start(subscriber_queue, {:sleep => 0.5, :thread_count => 5}) do |event, type|
      expect(event).to eq(message)
      expect(type).to eq(event_type)

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

end