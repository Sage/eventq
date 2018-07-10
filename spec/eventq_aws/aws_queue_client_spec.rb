require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueClient do
  let(:options) { { aws_account_number: '123' } }

  subject { described_class.new(options) }

  describe '#sqs' do
    specify do
      expect(subject.sqs).to be_a Aws::SQS::Client
    end
  end

  describe '#sns' do
    specify do
      expect(subject.sns).to be_a Aws::SNS::Client
    end
  end
end
