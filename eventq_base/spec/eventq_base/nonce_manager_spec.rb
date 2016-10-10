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
        expect(described_class.lifespan).to eq 3600000
      end
    end

    after do
      described_class.reset
    end

  end

  describe '#process' do
    let(:nonce) { SecureRandom.uuid }

    context 'when the NonceManager has NOT been configured' do
      before do
        described_class.reset
      end
      it 'should execute the process block' do
        expect(described_class).to receive(:process_without_nonce)
        described_class.process(nonce) do
          puts 'Processed'
        end
      end
    end
    context 'when the NonceManager has been configured' do
      before do
        described_class.configure(server: 'redis://redis:6379')
      end

      context 'and the nonce has NOT been processed before' do
        it 'should execute the process block' do
          expect(described_class).to receive(:process_with_nonce)
          described_class.process(nonce) do
            puts 'Processed'
          end
        end
      end
      context 'and the nonce has been processed before' do
        it 'should raise a NonceError' do
          described_class.process(nonce) do
            puts 'Processed'
          end

          expect { described_class.process(nonce) }.to raise_error(EventQ::NonceError)
        end
      end

      after do
        described_class.reset
      end
    end

  end
end