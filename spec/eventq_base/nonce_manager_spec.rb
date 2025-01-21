require 'spec_helper'

RSpec.describe EventQ::NonceManager do
  describe '#configure' do

    let(:server_url) { 'redis://server:6379' }
    let(:timeout) { 5000 }
    let(:lifespan) { 20000}
    let(:pool_size) { 1 }
    let(:pool_timeout) { 1 }

    context 'when all values are specified' do
      it 'should set the configuration values correctly' do
        described_class.configure(server: server_url, timeout: timeout, lifespan: lifespan, pool_size: pool_size, pool_timeout: pool_timeout)
        expect(described_class.server_url).to eq server_url
        expect(described_class.timeout).to eq timeout
        expect(described_class.lifespan).to eq lifespan
        expect(described_class.pool_size).to eq pool_size
        expect(described_class.pool_timeout).to eq pool_timeout
      end
    end

    context 'when only the server_url is specified' do
      it 'should set the server_url correctly and use the defaults for timeout & lifespan' do
        described_class.configure(server: server_url)
        expect(described_class.server_url).to eq server_url
        expect(described_class.timeout).to eq 10000
        expect(described_class.lifespan).to eq 3600
        expect(described_class.pool_size).to eq 5
        expect(described_class.pool_timeout).to eq 5
      end
    end

    after do
      described_class.reset
    end

  end

  describe '#lock' do
    let(:nonce) { SecureRandom.uuid }

    context 'when NonceManager has been configured' do
      before do
        described_class.configure(server: ENV.fetch('REDIS_ENDPOINT', 'redis://redis:6379'))
      end
      context 'when a nonce has NOT been used' do
        it 'should return true' do
          expect(described_class.lock(nonce)).to be true
        end
      end
      context 'when a nonce has already been used' do
        it 'should return false' do
          described_class.lock(nonce)
          expect(described_class.lock(nonce)).to be false
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
          expect(described_class.lock(nonce)).to be true
        end
      end
      context 'when a nonce has already been used' do
        it 'should return false' do
          described_class.lock(nonce)
          expect(described_class.lock(nonce)).to be true
        end
      end

      it 'should not attempt to hit redis' do
        expect_any_instance_of(Redis).not_to receive(:set)
        described_class.lock(nonce)
      end
    end

  end

  describe '#complete' do
    let(:nonce) { SecureRandom.uuid }
    context 'when NonceManager has been configured' do
      before do
        described_class.configure(server: ENV.fetch('REDIS_ENDPOINT', 'redis://redis:6379'))
        described_class.lock(nonce)
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
        described_class.configure(server: ENV.fetch('REDIS_ENDPOINT', 'redis://redis:6379'))
        described_class.lock(nonce)
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

  # this is a private method, but we want to make sure we correctly raise an error if a consumer tries to use
  # it directly to access the underlying connection pool without configuring the nonce manager first
  describe '.with_redis_connection' do
    context 'when the nonce manager has not been configured' do
      before do
        described_class.reset
      end

      it 'raises error' do
        expect { described_class.with_redis_connection { } }.to raise_error(EventQ::NonceManagerNotConfiguredError)
      end
    end
  end
end
