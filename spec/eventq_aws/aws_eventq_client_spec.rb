require 'spec_helper'

RSpec.describe EventQ::Amazon::EventQClient do

  let(:event_type) { 'test_queue1_event1' }
  let(:event) { 'Hello World' }

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new
  end

  subject { described_class.new(client: queue_client) }

  describe '#raise_event' do
    let(:response) { double('PublishResponse', message_id: message_id) }
    let(:message_id) { '123' }
    let(:message_context) { { 'foo' => 'bar' } }

    it 'publishes an SNS event' do
      expect(queue_client.sns).to receive(:publish) do |options|
        # expect(options[:topic_arn]).to match %r{arn:aws:sns:#{aws_region}:#{aws_account_number}:#{event_type}}

        message_json = JSON.parse(options[:message])
        expect(message_json['content']).to eql event
        expect(message_json['type']).to eql event_type
        expect(message_json['context']).to eql message_context

        expect(options[:subject]).to eql event_type
      end.and_return(response)

      expect(subject.raise_event(event_type, event, message_context)).to eql message_id
    end

    it 'registers the event_type before publishing an SNS event' do
      expect(subject).to receive(:register_event).with(event_type).once.ordered
      expect(subject).to receive(:with_prepared_message).once.ordered
      subject.raise_event(event_type, event)
    end
  end

  describe '#raise_event_in_queue' do
    let(:result) { double('SendMessageResult', message_id: message_id) }
    let(:message_id) { '123' }
    let(:queue_name) { 'What_happens_if_you_cut_the_queue_in_Britain' }
    let(:queue) do
      EventQ::Queue.new.tap do |queue|
        queue.name = queue_name
      end
    end
    let(:delay_seconds) { 23 }

    before do
      queue_client.sqs.create_queue(queue_name: queue.name)
    end

    it 'sends an event to SQS' do
      expect(queue_client.sqs).to receive(:send_message) do |options|
        outer_message_json = JSON.parse(options[:message_body])

        inner_message_json = JSON.parse(outer_message_json[EventQ::Amazon::QueueWorker::MESSAGE])
        expect(inner_message_json['content']).to eql event
        expect(inner_message_json['type']).to eql event_type

        expect(options[:delay_seconds]).to eql delay_seconds
      end.and_return(result)

      expect(subject.raise_event_in_queue(event_type, event, queue, delay_seconds)).to eql message_id
    end
  end

  describe '#register_event' do
    let(:event_type) { 'event_type' }
    context 'when an event is NOT already registered' do
      it 'should register the event, create the topic and return true' do
        expect(queue_client).to receive(:create_topic_arn).with(event_type).once
        expect(subject.register_event(event_type)).to be true
        known_types = subject.instance_variable_get(:@known_event_types)
        expect(known_types.include?(event_type)).to be true
      end
    end
    context 'when an event has already been registered' do
      before do
        known_types = subject.instance_variable_get(:@known_event_types)
        known_types << event_type
      end
      it 'should return true' do
        expect(queue_client).not_to receive(:create_topic_arn)
        expect(subject.register_event(event_type)).to be true
      end
    end
  end

  describe '#registered?' do
    let(:event_type) { 'event_type' }
    context 'when an event_type is registered' do
      before do
        known_types = subject.instance_variable_get(:@known_event_types)
        known_types << event_type
      end
      it 'should return true' do
        expect(subject.registered?(event_type)).to be true
      end
    end
    context 'when an event_type is NOT registered' do
      it 'should return false' do
        expect(subject.registered?(event_type)).to be false
      end
    end
  end
end
