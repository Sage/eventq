require 'spec_helper'

RSpec.describe EventQ::Queue do
  let(:queue) { described_class.new }

  describe '#log_settings' do
    before do
      @logged_message = nil
      allow(EventQ.logger).to receive(:info) do |&block|
        @logged_message = block.call
      end
    end

    it 'logs the default settings' do
      queue.log_settings

      expect(@logged_message).to eq(
        "[EventQ::Queue] - Settings: name='', allow_retry='false', allow_retry_back_off='false', " \
        "allow_exponential_back_off='false', dlq='', max_receive_count='30', max_retry_attempts='5', " \
        "max_retry_delay='5000', retry_delay='30000', retry_back_off_grace='0', retry_back_off_weight='1', " \
        "retry_jitter_ratio='0', require_signature='false'"
      )
    end

    it 'logs custom settings' do
      queue.name = 'MyQueue'
      queue.allow_retry = true
      queue.allow_retry_back_off = true
      queue.allow_exponential_back_off = true
      queue.dlq = 'MyDLQ'
      queue.max_receive_count = 50
      queue.max_retry_attempts = 10
      queue.max_retry_delay = 10000
      queue.retry_delay = 60000
      queue.retry_back_off_grace = 5
      queue.retry_back_off_weight = 2
      queue.retry_jitter_ratio = 100
      queue.require_signature = true

      queue.log_settings

      expect(@logged_message).to eq(
        "[EventQ::Queue] - Settings: name='MyQueue', allow_retry='true', allow_retry_back_off='true', " \
        "allow_exponential_back_off='true', dlq='MyDLQ', max_receive_count='50', max_retry_attempts='10', " \
        "max_retry_delay='10000', retry_delay='60000', retry_back_off_grace='5', retry_back_off_weight='2', " \
        "retry_jitter_ratio='100', require_signature='true'"
      )
    end
  end
end
