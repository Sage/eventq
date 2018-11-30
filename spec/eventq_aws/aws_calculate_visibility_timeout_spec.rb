require 'spec_helper'

RSpec.describe EventQ::Amazon::CalculateVisibilityTimeout do
  let(:max_timeout) { 43_200 }
  let(:retry_delay) { 30_000 }
  let(:max_retry_delay) { 100_000 }
  let(:retry_back_off_grace) { 20_000 }

  subject { described_class.new(max_timeout: max_timeout) }

  context 'when retry backoff is disabled' do
    let(:allow_retry_back_off) { false }

    it 'does not introduces backoff' do
      result = subject.call(
        retry_delay:          retry_delay,
        retry_attempts:       1,
        max_retry_delay:      max_retry_delay,
        retry_back_off_grace: retry_back_off_grace,
        allow_retry_back_off: allow_retry_back_off
      )

      expect(result).to eq(30)


      result = subject.call(
        retry_delay:          retry_delay,
        retry_attempts:       retry_back_off_grace + 100,
        max_retry_delay:      max_retry_delay,
        retry_back_off_grace: retry_back_off_grace,
        allow_retry_back_off: allow_retry_back_off
      )

      expect(result).to eq(30)
    end
  end

  context 'when retry backoff is enabled' do
    let(:allow_retry_back_off) { true }

    context 'when the retry_attempts is lower than the retry_back_off_grace' do
      it 'does not introduce backoff' do
        result = subject.call(
          retry_delay:          retry_delay,
          retry_attempts:       retry_back_off_grace - 1,
          max_retry_delay:      max_retry_delay,
          retry_back_off_grace: retry_back_off_grace,
          allow_retry_back_off: allow_retry_back_off
        )

        expect(result).to eq(30)
      end
    end

    context 'when the retry_attempts exceeds the retry_back_off_grace' do
      it 'it introduce backoff' do
        result = subject.call(
          retry_delay:          retry_delay,
          retry_attempts:       retry_back_off_grace + 2,
          max_retry_delay:      max_retry_delay,
          retry_back_off_grace: retry_back_off_grace,
          allow_retry_back_off: allow_retry_back_off
        )

        expect(result).to eq(60)
      end
    end
  end
end