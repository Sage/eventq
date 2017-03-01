require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueManager do

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new({ aws_account_number: EventQ.AWS_ACCOUNT_NUMBER, aws_region: 'eu-west-1' })
  end

  subject do
    EventQ::Amazon::QueueManager.new({ client: queue_client })
  end

  describe '#get_queue' do
    context 'when a queue does not exist' do
      it 'should create the queue' do

        queue = EventQ::Queue.new
        queue.name = SecureRandom.uuid.gsub('-','')
        queue.allow_retry = true
        queue.max_retry_attempts = 5
        queue.retry_delay = 30

        queue_url = subject.get_queue(queue)
        expect(queue_url).not_to be_nil

      end
    end

    context 'when a queue already exists' do
      it 'should update the the queue' do

        queue = EventQ::Queue.new
        queue.name = SecureRandom.uuid.gsub('-','')
        queue.allow_retry = true
        queue.max_retry_attempts = 5
        queue.retry_delay = 30

        queue_url = subject.create_queue(queue)
        expect(queue_url).not_to be_nil

        update_url = subject.get_queue(queue)

        expect(update_url).to eq(queue_url)

      end
    end
  end

  class TestEvent
  end

  describe '#topic_exists?' do
    context 'when a topic exists' do
      let(:event_type) { 'test-event' }
      before do
        queue_client.create_topic_arn(event_type)
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