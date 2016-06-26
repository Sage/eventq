require 'spec_helper'

RSpec.describe EventQ::Aws::EventQClient do

  it 'should raise an event object and be broadcast to a subscriber queue' do

    event_type = 'test_queue1_event1'
    subscriber_queue = Queue.new
    subscriber_queue.name = 'test_queue1'

    client = EventQ::Aws::QueueClient.new

    subscription_manager = EventQ::Aws::SubscriptionManager.new
    subscription_manager.subscribe(event_type, subscriber_queue)

    message = 'Hello World'

    id = subject.raise(event_type, message)
    puts "Message ID: #{id}"

    #sleep for 2 seconds to allow the aws message to be sent to the topic and broadcast to subscribers
    sleep(1)

    queue_manager = EventQ::Aws::QueueManager.new

    q = queue_manager.get_queue(subscriber_queue)

    puts '[QUEUE] waiting for message...'

    #request a message from the queue
    response = client.sqs.receive_message({
                                          queue_url: q,
                                          max_number_of_messages: 1,
                                          wait_time_seconds: 5,
                                          message_attribute_names: ['ApproximateReceiveCount']
                                      })

    expect(response.messages.length).to eq(1)

    msg = response.messages[0]
    msg_body = Oj.load(msg.body)
    payload = Oj.load(msg_body["Message"])
    puts "[QUEUE] - received message: #{payload}"

    #remove the message from the queue so that it does not get retried
    client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

    expect(payload).to_not be_nil
    expect(payload.content).to eq(message)

  end


end