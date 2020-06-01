# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EventQ::Amazon::DomainEventQClient do
  let(:queue_client) do
    EventQ::Amazon::QueueClient.new
  end

  subject { described_class.new(client: queue_client) }

  describe '#raise_event' do
    let(:response) { double('PublishResponse', message_id: message_id) }
    let(:message_id) { '123' }
    let(:event_name) { 'foobar' }
    let(:event) do
      {
        'foo_event' => {
          'id' => SecureRandom.uuid,
          'bar' => 'Foobar'
        }
      }
    end

    it 'registers the event' do
      expect(subject).to receive(:register_event).with(event_name, nil)

      subject.raise_event(event_name, event)
    end

    it 'raises an event with a domain message' do
      expect(queue_client.sns).to receive(:publish) do |options|
        message_json = JSON.parse(options[:message])
        expect(message_json['content']).to eql event
        expect(message_json['topic']).to eql event_name
      end.and_return(response)

      subject.raise_event(event_name, event)
    end
  end
end
