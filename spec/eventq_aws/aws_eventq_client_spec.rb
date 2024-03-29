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
      expect(subject).to receive(:register_event).with(event_type, nil).once.ordered
      expect(subject).to receive(:with_prepared_message).once.ordered
      subject.raise_event(event_type, event)
    end

    context 'when event.Correlation object provided' do
      let(:correlation_trace_id) { SecureRandom.uuid }
      let(:correlation) { { 'Trace' => correlation_trace_id } }
      let(:event) { double('Event', content: 'Hello world', Correlation: correlation) }

      it 'publishes an SNS event with correlation_trace_id set' do
        expect(queue_client.sns).to receive(:publish) do |options|
          message_json = JSON.parse(options[:message])
          expect(message_json['correlation_trace_id']).to eql correlation_trace_id
        end.and_return(response)

        expect(subject.raise_event(event_type, event, message_context)).to eql message_id
      end

      it 'publishes an SNS event with Correlation set' do
        expect(queue_client.sns).to receive(:publish) do |options|
          message_json = JSON.parse(options[:message])
          expect(message_json['Correlation']).to eql correlation
          expect(message_json['Correlation']['Trace']).to eql correlation_trace_id
        end.and_return(response)

        expect(subject.raise_event(event_type, event, message_context)).to eql message_id
      end
    end

    context 'when event.Correlation object not provided' do
      let(:event) { double('Event', content: 'Hello world') }

      it 'publishes an SNS event without correlation_trace_id set' do
        expect(queue_client.sns).to receive(:publish) do |options|
          message_json = JSON.parse(options[:message])
          expect(message_json['correlation_trace_id']).to be nil
        end.and_return(response)

        expect(subject.raise_event(event_type, event, message_context)).to eql message_id
      end

      it 'publishes an SNS event without Correlation set' do
        expect(queue_client.sns).to receive(:publish) do |options|
          message_json = JSON.parse(options[:message])
          expect(message_json['Correlation']).to be nil
        end.and_return(response)

        expect(subject.raise_event(event_type, event, message_context)).to eql message_id
      end
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
    let(:topic_arn) { 'topic:arn' }

    context 'when an event is NOT already registered' do
      it 'should register the event, create the topic and return the topic arn' do
        expect(queue_client.sns_helper)
          .to receive(:create_topic_arn)
          .with(event_type, nil)
          .once
          .and_return(topic_arn)

        expect(subject.register_event(event_type)).to eq topic_arn

        known_types = subject.instance_variable_get(:@known_event_types)
        expect(known_types[":#{event_type}"]).to eq topic_arn
      end
    end

    context 'when an event has already been registered' do
      before do
        known_types = subject.instance_variable_get(:@known_event_types)
        known_types[":#{event_type}"] = topic_arn
      end

      it 'should return the topic arn' do
        expect(queue_client.sns_helper).not_to receive(:create_topic_arn)
        expect(subject.register_event(event_type)).to eq topic_arn
      end
    end
  end

  describe '#registered?' do
    let(:event_type) { 'event_type' }
    let(:topic_arn) { 'topic:arn' }

    context 'when an event_type is registered' do
      before do
        known_types = subject.instance_variable_get(:@known_event_types)
        known_types[":#{event_type}"] = topic_arn
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
