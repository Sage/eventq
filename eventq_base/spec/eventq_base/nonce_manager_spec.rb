RSpec.describe EventQ::NonceManager do
  describe '#configure' do

    let(:server_url) { 'redis://server:6379' }
    let(:timeout) { 5000 }
    let(:lifespan) { 20000}

    context 'when all values are specified' do
      it 'should set the configuration values correctly' do
        described_class.configure(server: server_url, timeout: timeout, lifespan: lifespan)
        expect(described_class.server_url).to eq server_url
        expect(described_class.timeout).to eq timeout
        expect(described_class.lifespan).to eq lifespan
      end
    end

    context 'when only the server_url is specified' do
      it 'should set the server_url correctly and use the defaults for timeout & lifespan' do
        described_class.configure(server: server_url)
        expect(described_class.server_url).to eq server_url
        expect(described_class.timeout).to eq 10000
        expect(described_class.lifespan).to eq 3600
      end
    end

    after do
      described_class.reset
    end

  end

  describe '#is_allowed?' do
    let(:nonce) { SecureRandom.uuid }

    context 'when NonceManager has been configured' do
      before do
        described_class.configure(server: 'redis://redis:6379')
      end
      context 'when a nonce has NOT been used' do
        it 'should return true' do
          expect(described_class.is_allowed?(nonce)).to be true
        end
      end
      context 'when a nonce has already been used' do
        it 'should return false' do
          described_class.is_allowed?(nonce)
          expect(described_class.is_allowed?(nonce)).to be false
        end
      end
      after do
        described_class.reset
      end
    end

    context 'when NonceManager has NOT been configured' do
      before do
        described_class.reset
      end
      context 'when a nonce has NOT been used' do
        it 'should return true' do
          expect(described_class.is_allowed?(nonce)).to be true
        end
      end
      context 'when a nonce has already been used' do
        it 'should return false' do
          described_class.is_allowed?(nonce)
          expect(described_class.is_allowed?(nonce)).to be true
        end
      end
    end

  end

  describe '#complete' do
    let(:nonce) { SecureRandom.uuid }
    context 'when NonceManager has been configured' do
      before do
        described_class.configure(server: 'redis://redis:6379')
        described_class.is_allowed?(nonce)
      end
      it 'should extend the expiry of the nonce key' do
        expect(described_class.complete(nonce)).to eq true
      end
      after do
        described_class.reset
      end
    end

    context 'when NonceManager has NOT been configured' do
      before do
        described_class.reset
      end
      it 'should return true' do
        expect(described_class.complete(nonce)).to eq true
      end
    end
  end

  describe '#failed' do
    let(:nonce) { SecureRandom.uuid }
    context 'when NonceManager has been configured' do
      before do
        described_class.configure(server: 'redis://redis:6379')
        described_class.is_allowed?(nonce)
      end
      it 'should extend the expiry of the nonce key' do
        expect(described_class.failed(nonce)).to eq true
      end
      after do
        described_class.reset
      end
    end

    context 'when NonceManager has NOT been configured' do
      before do
        described_class.reset
      end
      it 'should return true' do
        expect(described_class.failed(nonce)).to eq true
      end
    end
  end

end