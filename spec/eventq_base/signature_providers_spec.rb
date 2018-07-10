require 'spec_helper'

RSpec.describe EventQ::SignatureProviders::Manager do
  describe '#get_provider' do
    context 'when a known provider type is specified' do
      it 'should return the provider class' do
        expect(subject.get_provider(EventQ::SignatureProviders::SHA256)).to be_a(EventQ::SignatureProviders::Sha256SignatureProvider)
      end
    end
    context 'when an unknown provider type is specified' do
      it 'should return the provider class' do
        expect{ subject.get_provider('unknown') }.to raise_error 'Invalid provider type specified: unknown'
      end
    end
  end

  describe '#validate_message' do
    let(:queue) do
      EventQ::Queue.new
    end
    let(:message) do
      EventQ::QueueMessage.new.tap do |e|
        e.content = {
            text: 'abc',
            number: 12
        }
      end
    end
    let(:signature_secret) { 'secret' }

    before do
      EventQ::Configuration.signature_secret = signature_secret
    end

    let(:provider) { EventQ::SignatureProviders::Sha256SignatureProvider.new }

    context 'when a queue does NOT require signed messages' do
      context 'and a message is signed' do
        context 'with a valid signature' do
          before do
            message.signature = provider.write(message: message, secret: signature_secret)
          end
          it 'should return true' do
            expect(subject.validate_signature(message: message, queue: queue)).to be true
          end
        end
        context 'with an invalid signature' do
          before do
            message.signature = provider.write(message: message, secret: 'invalid')
          end
          it 'should raise error' do
            expect{subject.validate_signature(message: message, queue: queue)}.to raise_error(EventQ::Exceptions::InvalidSignatureException)
          end
        end
      end
      context 'and a message is NOT signed' do
        it 'should return true' do
          expect(subject.validate_signature(message: message, queue: queue)).to be true
        end
      end
    end
    context 'when a queue does require signed messages' do
      before do
        queue.require_signature = true
      end
      context 'and a message is signed' do
        context 'with a valid signature' do
          before do
            message.signature = provider.write(message: message, secret: signature_secret)
          end
          it 'should return true' do
            expect(subject.validate_signature(message: message, queue: queue)).to be true
          end
        end
        context 'with an invalid signature' do
          before do
            message.signature = provider.write(message: message, secret: 'invalid')
          end
          it 'should raise error' do
            expect{subject.validate_signature(message: message, queue: queue)}.to raise_error(EventQ::Exceptions::InvalidSignatureException)
          end
        end
      end
      context 'and a message is NOT signed' do
        it 'should raise error' do
          expect{subject.validate_signature(message: message, queue: queue)}.to raise_error(EventQ::Exceptions::InvalidSignatureException)
        end
      end
    end
  end
end
