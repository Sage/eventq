require 'spec_helper'

RSpec.describe EventQ::Amazon::QueueWorker do

  describe '#deserialize_message' do

    context 'when serialization provider is OJ_PROVIDER' do
      before do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end

      context 'when payload is for a known type' do
        let(:a) do
          A.new.tap do |a|
            a.text = 'ABC'
          end
        end

        let(:payload) { Oj.dump(a) }

        it 'should deserialize the message into an object of the known type' do
          message = subject.deserialize_message(payload)
          expect(message).to be_a(A)
          expect(message.text).to eq('ABC')
        end
      end

      context 'when payload is for an unknown type' do
        let(:a) do
          A.new.tap do |a|
            a.text = 'ABC'
          end
        end
        let(:payload) do
          string = Oj.dump(a)
          JSON.load(string.sub('"^o":"A"', '"^o":"B"'))
        end
        let(:message) do
          EventQ::QueueMessage.new.tap do |m|
            m.content = payload
          end
        end
        let(:json) do
          Oj.dump(message)
        end

        it 'should deserialize the message into a Hash' do
          message = subject.deserialize_message(json)
          expect(message.content).to be_a(Hash)
          expect(message.content[:text]).to eq('ABC')
        end
      end
    end

    context 'when serialization provider is JSON_PROVIDER' do
      before do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::JSON_PROVIDER
      end

      let(:payload) do
        {
            content: { text: 'ABC' }
        }
      end
      let(:json) do
        JSON.dump(payload)
      end

      it 'should deserialize payload' do
        message = subject.deserialize_message(json)
        expect(message).to be_a(EventQ::QueueMessage)
        expect(message.content).to be_a(Hash)
        expect(message.content[:text]).to eq('ABC')
      end

      after do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
    end
  end
end

class A
  attr_accessor :text
end
