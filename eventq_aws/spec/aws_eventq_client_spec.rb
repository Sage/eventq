require 'spec_helper'

RSpec.describe EventQ::Amazon::EventQClient do

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

  context 'when EventQ.namespace is NOT specified' do
    it 'should raise an event object and be broadcast to a subscriber queue' do

      event_type = 'test_queue1_event1'
      subscriber_queue = EventQ::Queue.new
      subscriber_queue.name = SecureRandom.uuid

      subscription_manager.subscribe(event_type, subscriber_queue)

      message = 'Hello World'

      id = eventq_client.raise_event(event_type, message)
      puts "Message ID: #{id}"

      #sleep for 2 seconds to allow the aws message to be sent to the topic and broadcast to subscribers
      sleep(1)

      q = queue_manager.get_queue(subscriber_queue)

      puts '[QUEUE] waiting for message...'

      #request a message from the queue
      response = queue_client.sqs.receive_message({
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
      queue_client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

      expect(payload).to_not be_nil
      expect(payload.content).to eq(message)

    end
  end

  context 'when EventQ.namespace is specified' do

    before do
      EventQ.namespace = 'test'
    end

    it 'should raise an event object and be broadcast to a subscriber queue' do

      event_type = 'test_queue1_event1'
      subscriber_queue = EventQ::Queue.new
      subscriber_queue.name = SecureRandom.uuid

      subscription_manager.subscribe(event_type, subscriber_queue)

      message = 'Hello World'

      id = eventq_client.raise_event(event_type, message)
      puts "Message ID: #{id}"

      #sleep for 2 seconds to allow the aws message to be sent to the topic and broadcast to subscribers
      sleep(1)

      q = queue_manager.get_queue(subscriber_queue)

      puts '[QUEUE] waiting for message...'

      #request a message from the queue
      response = queue_client.sqs.receive_message({
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
      queue_client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

      expect(payload).to_not be_nil
      expect(payload.content).to eq(message)

    end

    after do
      EventQ.namespace = nil
    end
  end

end