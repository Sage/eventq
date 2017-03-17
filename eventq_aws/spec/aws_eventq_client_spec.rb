require 'spec_helper'

RSpec.describe EventQ::Amazon::EventQClient do

  let(:aws_account_number) { '123456789012' }
  let(:aws_region) { 'eu-west-1' }
  let(:event_type) { 'test_queue1_event1' }
  let(:event) { 'Hello World' }

  let(:queue_client) do
    EventQ::Amazon::QueueClient.new(aws_account_number: aws_account_number, aws_region: aws_region)
  end

  subject { described_class.new(client: queue_client) }

  describe '#raise_event' do
    let(:response) { double('PublishResponse', message_id: message_id) }
    let(:message_id) { '123' }

    it 'publishes an SNS event' do
      expect(queue_client.sns).to receive(:publish) do |options|
        expect(options[:topic_arn]).to match %r{arn:aws:sns:#{aws_region}:#{aws_account_number}:#{event_type}}

        message_json = JSON.parse(options[:message])
        expect(message_json['content']).to eql event
        expect(message_json['type']).to eql event_type

        expect(options[:subject]).to eql event_type
      end.and_return(response)

      expect(subject.raise_event(event_type, event)).to eql message_id
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
    let(:aws_sqs_client) { Aws::SQS::Client.new(stub_responses: true) }

    before do
      allow(queue_client).to receive(:sqs).and_return(aws_sqs_client)
    end

    it 'sends an event to SQS' do
      expect(queue_client.sqs).to receive(:send_message) do |options|
        message_json = JSON.parse(options[:message_body])
        expect(message_json['content']).to eql event
        expect(message_json['type']).to eql event_type

        expect(options[:delay_seconds]).to eql delay_seconds
      end.and_return(result)

      expect(subject.raise_event_in_queue(event_type, event, queue, delay_seconds)).to eql message_id
    end
  end
end
