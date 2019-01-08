require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueClient do
  describe '#sqs' do
    around do |example|
      previous = ENV['AWS_SQS_ENDPOINT']
      example.run
      ENV['AWS_SQS_ENDPOINT'] = previous
    end

    specify do
      expect(subject.sqs).to be_a Aws::SQS::Client
    end

    context 'when no custom SQS endpoint defined' do
      it 'does not pass in custom options to client' do
        ENV['AWS_SQS_ENDPOINT'] = nil
        expect(Aws::SQS::Client).to receive(:new).and_call_original
        subject.sqs
      end
    end

    context 'when custom SQS endpoint is defined' do
      it 'supplies the endpoint: option to the client' do
        ENV['AWS_SQS_ENDPOINT'] = 'http://somewhere:555'
        expect(Aws::SQS::Client).to receive(:new).with({ endpoint: 'http://somewhere:555', verify_checksums: false }).and_call_original
        subject.sqs
      end
    end
  end

  describe '#get_queue_url' do
    let(:queue) { OpenStruct.new(name: "test_queue_#{SecureRandom.hex(2)}") }

    context 'when queue arn does not exist' do
      it 'returns nil' do
        expect(subject.sqs_helper.get_queue_url(queue)).to be_nil
      end
    end

    context 'when queue url is cached' do
      before do
        EventQ::Amazon::SQS.class_variable_get(:@@queue_urls)[queue.name] = 'something_dummy_url'
      end

      it 'does not call AWS' do
        expect(subject.sqs).to_not receive(:get_queue_url)
        expect(subject.sqs_helper.get_queue_url(queue)).to eq 'something_dummy_url'
      end
    end

    context 'when queue exists in AWS' do
      before do
        subject.sqs.create_queue(queue_name: queue.name)
      end
      it 'calls AWS and populates cache' do
        expect(subject.sqs).to receive(:get_queue_url).and_call_original
        expect(subject.sqs_helper.get_queue_url(queue)).to include queue.name
      end
    end
  end

  describe '#get_queue_arn' do
    let(:queue) { OpenStruct.new(name: "test_queue_#{SecureRandom.hex(2)}") }

    context 'when queue arn does not exist' do
      it 'returns nil' do
        expect(subject.sqs_helper.get_queue_arn(queue)).to be_nil
      end
    end

    context 'when queue arn is cached' do
      before do
        EventQ::Amazon::SQS.class_variable_get(:@@queue_arns)[queue.name] = 'something_dummy_arn'
      end

      it 'does not call AWS' do
        expect(subject.sqs).to_not receive(:get_queue_url)
        expect(subject.sqs_helper.get_queue_arn(queue)).to eq 'something_dummy_arn'
      end
    end

    context 'when queue exists in AWS' do
      before do
        subject.sqs.create_queue(queue_name: queue.name)
      end
      it 'calls AWS and populates cache' do
        expect(subject.sqs).to receive(:get_queue_url).and_call_original
        expect(subject.sqs).to receive(:get_queue_attributes).and_call_original
        arn = subject.sqs_helper.get_queue_arn(queue)
        expect(arn).to include queue.name
        expect(arn).to include 'arn'
      end
    end
  end

  describe '#sns' do
    around do |example|
      previous = ENV['AWS_SNS_ENDPOINT']
      example.run
      ENV['AWS_SNS_ENDPOINT'] = previous
    end

    specify do
      expect(subject.sns).to be_a Aws::SNS::Client
    end

    context 'when no custom SNS endpoint defined' do
      it 'does not pass in custom endpoint to client' do
        ENV['AWS_SNS_ENDPOINT'] = nil
        expect(Aws::SNS::Client).to receive(:new) { |x| expect(x[:endpoint]).to be_nil }
        subject.sns
      end
    end

    context 'when custom SNS endpoint defined' do
      it 'supplies the custom endpoint to client' do
        ENV['AWS_SNS_ENDPOINT'] = 'http://somewhere:556'
        expect(Aws::SNS::Client).to receive(:new) { |x| expect(x[:endpoint]).to eq 'http://somewhere:556' }
        subject.sns
      end
    end
  end

  describe '#create_topic_arn' do
    let(:event_type) { "test_event_#{SecureRandom.hex(2)}" }
    let(:region) { nil }
    let(:topic_key) { "#{region}:#{event_type}" }

    context 'when topic ARN is stored in cache' do
      it 'does not make a call to AWS to try and create again' do
        subject.sns_helper.create_topic_arn(event_type)
        expect(subject.sns).to_not receive(:create_topic)
        expect(EventQ::Amazon::SNS.class_variable_get(:@@topic_arns)[topic_key]).to_not be_empty
        subject.sns_helper.create_topic_arn(event_type)
      end
    end

    context 'when topic ARN does NOT exist in SNS' do
      it 'creates the topic and caches it' do
        expect(subject.sns).to receive(:create_topic).and_call_original
        expect(subject.sns_helper.create_topic_arn(event_type)).to include event_type
        expect(EventQ::Amazon::SNS.class_variable_get(:@@topic_arns)[topic_key]).to_not be_empty
      end
    end
  end

  describe '#get_topic_arn' do
    let(:event_type) { "test_event_#{SecureRandom.hex(2)}" }
    let(:region) { nil }
    let(:topic_key) { "#{region}:#{event_type}" }

    context 'when arn does not exist' do
      it 'returns nil' do
        expect(subject.sns_helper.get_topic_arn(event_type)).to be_nil
      end
    end

    context 'when arn is cached' do
      before do
        EventQ::Amazon::SNS.class_variable_get(:@@topic_arns)[topic_key] = 'something_dummy_arn'
      end

      it 'does not call AWS' do
        expect(subject.sns).to_not receive(:list_topics)
        expect(subject.sns_helper.get_topic_arn(event_type)).to eq 'something_dummy_arn'
      end
    end
  end
end
