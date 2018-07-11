require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueClient do
  let(:options) { { aws_account_number: '123' } }

  subject { described_class.new(options) }

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
end
