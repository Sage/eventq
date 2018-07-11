require 'spec_helper'

RSpec.describe EventQ::Amazon::EventQClient, integration: true do

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

  let(:class_kit) { ClassKit::Helper.new }

  let(:event_type) { 'test_queue1_event1' }
  let(:message) { 'Hello World' }
  let(:message_context) { { 'foo' => 'bar' } }

  describe '#publish' do
    it 'should raise an event object and be broadcast to a subscriber queue' do
      subscription_manager.subscribe(event_type, subscriber_queue)

      id = eventq_client.publish(topic: event_type, event: message, context: message_context)
      EventQ.logger.debug { "Message ID: #{id}" }

      # sleep for 2 seconds to allow the aws message to be sent to the topic and broadcast to subscribers
      sleep(1)

      q = queue_manager.get_queue(subscriber_queue)

      EventQ.logger.debug {  '[QUEUE] waiting for message...' }

      # request a message from the queue
      response = queue_client.sqs.receive_message({
                                                      queue_url: q,
                                                      max_number_of_messages: 1,
                                                      wait_time_seconds: 5,
                                                      message_attribute_names: ['ApproximateReceiveCount']
                                                  })

      expect(response.messages.length).to eq(1)

      msg = response.messages[0]
      msg_body = JSON.load(msg.body)
      payload_hash = JSON.load(msg_body["Message"])
      payload = class_kit.from_hash(hash: payload_hash, klass: EventQ::QueueMessage)
      EventQ.logger.debug {  "[QUEUE] - received message: #{payload}" }

      #remove the message from the queue so that it does not get retried
      queue_client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

      expect(payload).to_not be_nil
      expect(payload.content).to eq(message)
      expect(payload.context).to eq(message_context)
    end
  end

  describe '#raise_event' do

    shared_examples 'any event raising' do

      it 'should raise an event object and be broadcast to a subscriber queue' do
        subscription_manager.subscribe(event_type, subscriber_queue)

        id = eventq_client.raise_event(event_type, message, message_context)
        EventQ.logger.debug {  "Message ID: #{id}" }

        #sleep for 2 seconds to allow the aws message to be sent to the topic and broadcast to subscribers
        sleep(1)

        q = queue_manager.get_queue(subscriber_queue)

        EventQ.logger.debug {  '[QUEUE] waiting for message...' }

        #request a message from the queue
        response = queue_client.sqs.receive_message({
                                                        queue_url: q,
                                                        max_number_of_messages: 1,
                                                        wait_time_seconds: 5,
                                                        message_attribute_names: ['ApproximateReceiveCount']
                                                    })

        expect(response.messages.length).to eq(1)

        msg = response.messages[0]
        msg_body = JSON.load(msg.body)
        payload_hash = JSON.load(msg_body["Message"])
        payload = class_kit.from_hash(hash: payload_hash, klass: EventQ::QueueMessage)
        EventQ.logger.debug {  "[QUEUE] - received message: #{payload}" }

        #remove the message from the queue so that it does not get retried
        queue_client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

        expect(payload).to_not be_nil
        expect(payload.content).to eq(message)
        expect(payload.context).to eq(message_context)
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
    let(:queue_name) { 'How_do_I_learn_to_queue_like_a_British_person_' + SecureRandom.hex(2) }
    let(:queue) do
      EventQ::Queue.new.tap do |queue|
        queue.name = queue_name
      end
    end
    let(:delay_seconds) { 3 }

    xit 'should send a message to SQS with a delay' do
      queue_manager.create_queue(queue)
      queue_client.sqs.purge_queue(queue_url: queue_client.get_queue_url(queue)[0])

      id = eventq_client.raise_event_in_queue(event_type, message, queue, delay_seconds)
      EventQ.logger.debug {  "Message ID: #{id}" }

      EventQ.logger.debug {  '[QUEUE] waiting for message...' }

      #request a message from the queue
      queue_url, _ = queue_client.get_queue_url(queue)
      response = queue_client.sqs.receive_message(
                                                      queue_url: queue_url,
                                                      max_number_of_messages: 1,
                                                      wait_time_seconds: 1,
                                                      message_attribute_names: ['ApproximateReceiveCount']
                                                  )

      expect(response.messages.length).to eq(0)

      sleep(2)

      response = queue_client.sqs.receive_message(
          queue_url: queue_url,
          max_number_of_messages: 1,
          wait_time_seconds: 3,
          message_attribute_names: ['ApproximateReceiveCount']
      )

      expect(response.messages.length).to eq(1)

      msg = response.messages[0]
      payload_hash = JSON.load(JSON.load(msg.body)[EventQ::Amazon::QueueWorker::MESSAGE])
      payload = class_kit.from_hash(hash: payload_hash, klass: EventQ::QueueMessage)

      EventQ.logger.debug {  "[QUEUE] - received message: #{msg}" }

      #remove the message from the queue so that it does not get retried
      queue_client.sqs.delete_message(queue_url: queue_url, receipt_handle: msg.receipt_handle)

      expect(payload.content).to eq(message)
    end
  end
end
