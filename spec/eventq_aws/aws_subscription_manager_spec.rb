require 'spec_helper'

RSpec.describe EventQ::Amazon::SubscriptionManager do
  subject { described_class.new(client: queue_client, queue_manager: queue_manager) }

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new
  end

  let(:queue_manager) do
    EventQ::Amazon::QueueManager.new({ client: queue_client })
  end

  let(:subscriber_queue) do
    EventQ::Queue.new.tap do |sq|
      sq.name = SecureRandom.uuid.to_s
    end
  end

  let(:event_type) { SecureRandom.uuid }

  describe '#subscribe' do
    context 'when Queue.isolated is false' do
      it 'creates a topic if it does not exist' do
        expect { subject.subscribe(event_type, subscriber_queue) }.to_not raise_error
      end
    end

    context 'when Queue.isolated is true' do
      it 'raises an error if topic does not exist' do
        subscriber_queue.isolated = true
        expect { subject.subscribe(event_type, subscriber_queue) }.to raise_error(EventQ::Exceptions::EventTypeNotFound)
      end
    end

    context 'existing subscription' do
      let(:topic_arn) { 'dummy_topic_arn' }
      let(:queue_arn) { 'dummy_queue_arn' }

      before do
        allow_any_instance_of(EventQ::Amazon::SNS).to receive(:public_send).and_return(topic_arn)
        allow_any_instance_of(EventQ::Amazon::SQS).to receive(:get_queue_arn).and_return(queue_arn)
        allow_any_instance_of(Aws::SNS::Client).to receive(:list_subscriptions).and_return(subscriptions)
      end

      context 'does not exist for the current queue/topic' do
        let(:subscriptions) { double(subscriptions: []) }

        it 'subscribes to the topic' do
          expect_any_instance_of(Aws::SNS::Client).to receive(:subscribe)
          subject.subscribe(event_type, subscriber_queue)
        end
      end

      context 'already exists for the current queue/topic' do
        let(:subscriptions) do
          double(
            subscriptions: [
              double(topic_arn: topic_arn, endpoint: queue_arn)
            ]
          )
        end

        it 'does not subscribe to the topic again' do
          expect_any_instance_of(Aws::SNS::Client).not_to receive(:subscribe)
          subject.subscribe(event_type, subscriber_queue)
        end
      end
    end

    context 'topic_namespaces is provided' do
      let(:namespaces) { ['foo', 'bar', 'baz'] }
      let(:topic_arn) { 'arn:aws:sns:us-east-1:123456789012:foo-dummy-topic' }
      let(:queue_arn) { 'dummy_queue_arn' }
      let(:subscriptions) { double(subscriptions: []) }

      before do
        allow(EventQ).to receive(:namespace).and_return('foo')
        allow_any_instance_of(EventQ::Amazon::SNS).to receive(:public_send).and_return(topic_arn)
        allow_any_instance_of(EventQ::Amazon::SQS).to receive(:get_queue_arn).and_return(queue_arn)
        allow_any_instance_of(Aws::SNS::Client).to receive(:list_subscriptions).and_return(subscriptions)
      end

      it 'subscribes the queue to the topics for each namespace provided' do
        expect_any_instance_of(Aws::SNS::Client).to receive(:subscribe).with(
          topic_arn: topic_arn,
          protocol: 'sqs',
          endpoint: queue_arn
        )
        expect_any_instance_of(Aws::SNS::Client).to receive(:subscribe).with(
          topic_arn: 'arn:aws:sns:us-east-1:123456789012:bar-dummy-topic',
          protocol: 'sqs',
          endpoint: queue_arn
        )
        expect_any_instance_of(Aws::SNS::Client).to receive(:subscribe).with(
          topic_arn: 'arn:aws:sns:us-east-1:123456789012:baz-dummy-topic',
          protocol: 'sqs',
          endpoint: queue_arn
        )
        expect_any_instance_of(EventQ::Amazon::SNS).to receive(:create_topic_arn).exactly(3).times
        subject.subscribe(event_type, subscriber_queue, nil, nil, namespaces)
      end

      context 'queue is isolated' do
        before do
          allow_any_instance_of(EventQ::Amazon::SNS).to receive(:public_send).and_return(topic_arn)
        end

        it 'does not create the topic' do
          subscriber_queue.isolated = true
          expect_any_instance_of(Aws::SNS::Client).not_to receive(:create_topic)
          expect_any_instance_of(Aws::SNS::Client).to receive(:subscribe).exactly(3).times
          subject.subscribe(event_type, subscriber_queue, nil, nil, namespaces)
        end
      end
    end
  end
end
