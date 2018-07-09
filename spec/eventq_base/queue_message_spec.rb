require 'spec_helper'

RSpec.describe EventQ::QueueMessage do
  describe '#sign' do
    before do
      allow(EventQ::Configuration).to receive(:signature_secret).and_return signature_secret
    end

    let(:signature_provider) { double('SignatureProvider') }

    context 'when a secret is configured' do
      let(:signature_secret) { 's3cr3t' }

      specify do
        expect(signature_provider).to receive(:write).with(message: subject, secret: signature_secret)
        subject.sign(signature_provider)
      end
    end

    context 'when no secret is configured' do
      let(:signature_secret) { nil }

      specify do
        expect(signature_provider).not_to receive(:write)
        subject.sign(signature_provider)
      end
    end
  end
end
