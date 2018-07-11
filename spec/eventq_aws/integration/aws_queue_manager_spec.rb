require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueManager, integration: true do

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new
  end

  subject do
    EventQ::Amazon::QueueManager.new({ client: queue_client })
  end

  describe '#get_queue' do
    let(:queue) do
      EventQ::Queue.new.tap do |queue|
        queue.name = SecureRandom.uuid.gsub('-','')
        queue.allow_retry = true
        queue.max_retry_attempts = 5
        queue.retry_delay = 30
        queue.dlq = dlq
      end
    end

    let(:dlq) { nil }

    context 'when a queue does not exist' do
      it 'creates the queue' do
        queue_url = subject.get_queue(queue)
        expect(queue_url).not_to be_nil
      end
    end

    context 'when a queue already exists' do
      it 'updates the queue' do
        queue_url = subject.create_queue(queue)
        expect(queue_url).not_to be_nil

        update_url = subject.get_queue(queue)

        expect(update_url).to eq(queue_url)
      end
    end

    context 'when a queue has a dead letter queue' do
      let(:dlq) do
        EventQ::Queue.new.tap do |queue|
          queue.name = SecureRandom.uuid.gsub('-','')
          queue.allow_retry = true
          queue.max_retry_attempts = 5
          queue.retry_delay = 30
        end
      end

      context 'and the dead letter queue does not exist' do
        it 'creates the dead letter queue' do
          expect(subject).to receive(:create_queue).with(dlq).and_call_original
          expect(subject).to receive(:create_queue).with(queue).and_call_original
          queue_url = subject.get_queue(queue)
          expect(queue_url).not_to be_nil
        end
      end

      context 'and the dead letter queue exists' do
        it 'updates the dead letter queue' do
          queue_url = subject.create_queue(dlq)
          expect(queue_url).not_to be_nil

          expect(subject).to receive(:update_queue).with(dlq).and_call_original
          queue_url = subject.get_queue(queue)
          expect(queue_url).not_to be_nil
        end
      end
    end
  end

  class TestEvent
  end

  describe '#topic_exists?' do
    context 'when a topic exists' do
      let(:event_type) { 'test-event' }
      before do
        queue_client.sns_helper.create_topic_arn(event_type)
      end
      it 'should return true' do
        expect(subject.topic_exists?(event_type)).to be true
      end
    end

    context 'when a topic does NOT exists' do
      let(:event_type) { 'unknown-test-event' }
      it 'should return true' do
        expect(subject.topic_exists?(event_type)).to be false
      end
    end
  end

end
