require 'spec_helper'

RSpec.describe EventQ::SignatureProviders::Sha256SignatureProvider do
  let(:secret) { 'secret' }
  let(:message_content) do
    {
      text: 'abcdef',
      number: 15,
      date: '2017-03-06T14:52:12'
    }
  end
  let(:message) do
    EventQ::QueueMessage.new.tap do |e|
      e.content = message_content
    end
  end

  describe '#write' do
    before do
      allow(EventQ::SerializationProviders::Manager).to receive(:new).and_return(serialization_provider_manager)
      allow(serializer).to receive(:serialize).with(message.content).and_return(content_as_json)
    end

    let(:serialization_provider_manager) { double('SerializationProviders::Manager', get_provider: serializer) }
    let(:serializer) { double('Serializer') }
    let(:content_as_json) { message_content.to_json }
    let(:expected) { "bwxKyNx/JK+uG6Vf8Ug82zPD1MSvsOq5CFfXikS497U=\n" }

    specify do
      expect(subject.write(secret: secret, message: message)).to eql expected
    end
  end

  describe '#valid?' do
    context 'when a valid signature is present' do
      before do
        message.signature = subject.write(message: message, secret: secret)
      end
      it 'should return true' do
        expect(subject.valid?(message: message, secret: secret)).to be true
      end
    end
    context 'when an invalid signature is present' do
      before do
        message.signature = 'invalid'
      end
      it 'should return false' do
        expect(subject.valid?(message: message, secret: secret)).to be false
      end
    end
  end
end
