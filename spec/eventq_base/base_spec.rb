require 'spec_helper'

RSpec.describe EventQ do
  describe '#create_queue_name' do
    let(:queue) { EventQ::Queue.new }

    before do
      queue.name = 'bogus_queue'
      allow(EventQ).to receive(:namespace) { 'test' }
    end

    it 'creates the queue name with a default delimiter' do
      expect(EventQ.create_queue_name(queue)).to eq 'test-bogus_queue'
    end

    it 'allows the queue name to have a custom delimeter' do
      queue.namespace_delimiter = '++'
      expect(EventQ.create_queue_name(queue)).to eq 'test++bogus_queue'
    end
  end
end
