require 'spec_helper'

RSpec.describe EventQ::Amazon::CalculateVisibilityTimeout do
  let(:max_timeout) { 43_200 }      # 43_200s (12h)
  let(:retry_delay) { 30_000 }      # 30s
  let(:max_retry_delay) { 100_000 } #100s
  let(:retry_back_off_grace) { 1000 }

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

      expect(result).to eq(ms_to_seconds(retry_delay))


      result = subject.call(
        retry_delay:          retry_delay,
        retry_attempts:       retry_back_off_grace + 100,
        max_retry_delay:      max_retry_delay,
        retry_back_off_grace: retry_back_off_grace,
        allow_retry_back_off: allow_retry_back_off
      )

      expect(result).to eq(ms_to_seconds(retry_delay))
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

        expect(result).to eq(ms_to_seconds(retry_delay))
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

        expect(result).to eq(ms_to_seconds(retry_delay) * 2)
      end
    end

    context 'when the visible_timeout exceeds the max_retry_delay' do
      it 'returns the max_retry_delay' do
        result = subject.call(
          retry_delay:          retry_delay,
          retry_attempts:       retry_back_off_grace + 100_000,
          max_retry_delay:      max_retry_delay,
          retry_back_off_grace: retry_back_off_grace,
          allow_retry_back_off: allow_retry_back_off
        )

        expect(result).to eq(ms_to_seconds(max_retry_delay))
      end
    end

    context 'when the visible_timeout is bigger than max_timeout' do
      it 'the visible_timeout is set to max_timeout' do
        result = subject.call(
          retry_delay:          retry_delay,
          retry_attempts:       retry_back_off_grace + 100_000,
          max_retry_delay:      50_000_000,
          retry_back_off_grace: retry_back_off_grace,
          allow_retry_back_off: allow_retry_back_off
        )

        expect(result).to eq(max_timeout)
      end
    end
  end

  def ms_to_seconds(value)
    value/1000
  end
end