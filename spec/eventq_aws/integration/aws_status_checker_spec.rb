require 'spec_helper'

RSpec.describe EventQ::Amazon::StatusChecker, integration: true do

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new
  end

  let(:queue_manager) do
    EventQ::Amazon::QueueManager.new({ client: queue_client })
  end

  subject do
    EventQ::Amazon::StatusChecker.new(queue_manager: queue_manager, client: nil)
  end

  describe '#queue?' do
    let(:queue) do
      EventQ::Queue.new.tap do |e|
        e.name = SecureRandom.uuid
      end
    end

    context 'when a queue can be connected to' do
      before do
        queue_manager.create_queue(queue)
      end
      it 'should return true' do
        expect(subject.queue?(queue)).to be true
      end
    end

    context 'when a queue cant be connected to' do
      it 'should return false' do
        expect(subject.queue?(queue)).to be false
      end
    end
  end

  describe '#event_type?' do
    let(:event_type) { SecureRandom.uuid }
    context 'when an event_type can be connected to' do
      before do
        queue_client.create_topic_arn(event_type)
      end
      it 'should return true' do
        expect(subject.event_type?(event_type)).to be true
      end
    end

    context 'when an event_type can NOT be connected to' do
      it 'should return false' do
        expect(subject.event_type?(event_type)).to be false
      end
    end
  end

end
