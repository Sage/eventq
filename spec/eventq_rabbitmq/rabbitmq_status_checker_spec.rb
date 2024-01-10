require 'spec_helper'

RSpec.describe EventQ::RabbitMq::StatusChecker do

  let(:client) do
    EventQ::RabbitMq::QueueClient.new({ endpoint: ENV.fetch('RABBITMQ_ENDPOINT', 'rabbitmq') })
  end

  subject do
    EventQ::RabbitMq::StatusChecker.new(client: client, queue_manager: EventQ::RabbitMq::QueueManager.new)
  end

  describe '#queue?' do
    let(:queue) do
      EventQ::Queue.new.tap do |e|
        e.name = SecureRandom.uuid
      end
    end
    context 'when a queue can be connected to' do
      it 'should return true' do
        expect(subject.queue?(queue)).to be true
      end
    end
    context 'when a queue cant be connected to' do
      let(:client) do
        EventQ::RabbitMq::QueueClient.new({ endpoint: 'unknown' })
      end
      it 'should return false' do
        expect(subject.queue?(queue)).to be false
      end
    end
  end

  describe '#event_type?' do
    let(:event_type) { SecureRandom.uuid }
    context 'when an event_type can be connected to' do
      it 'should return true' do
        expect(subject.event_type?(event_type)).to be true
      end
    end
    context 'when an event_type can NOT be connected to' do
      let(:client) do
        EventQ::RabbitMq::QueueClient.new({ endpoint: 'unknown' })
      end
      it 'should return false' do
        expect(subject.event_type?(event_type)).to be false
      end
    end
  end

  it 'should pass' do

  end

end
