RSpec.describe EventQ::SignatureProviders::Sha256SignatureProvider do
  let(:secret) { 'secret' }
  let(:message) do
    EventQ::QueueMessage.new.tap do |e|
      e.content = {
          text: 'abcdef',
          number: 15,
          date: DateTime.now
      }
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