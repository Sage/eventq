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
        expect { subject.subscribe(event_type, subscriber_queue) }.to raise_error
      end
    end
  end
end
