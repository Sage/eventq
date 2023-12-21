require 'spec_helper'

RSpec.describe EventQ::Amazon::CalculateVisibilityTimeout do
  let(:allow_retry_back_off) { false }
  let(:allow_exponential_back_off) { false }

  let(:max_timeout) { 43_200 }        # 43_200s (12h)
  let(:max_retry_delay) { 100_000 }   # 100s
  let(:retry_delay) { 30_000 }        # 30s
  let(:retry_back_off_grace) { 1000 } # iterations before the backoff grace quicks in
  let(:retry_back_off_weight) { 1 }   # backoff multiplier
  let(:retry_jitter_ratio) { 0 }      # ratio for randomness on retry delay

  let(:queue_settings) do
    {
      allow_retry_back_off:       allow_retry_back_off,
      allow_exponential_back_off: allow_exponential_back_off,
      max_retry_delay:            max_retry_delay,
      retry_delay:                retry_delay,
      retry_back_off_grace:       retry_back_off_grace,
      retry_back_off_weight:      retry_back_off_weight,
      retry_jitter_ratio:         retry_jitter_ratio
    }
  end

  subject { described_class.new(max_timeout: max_timeout) }

  context 'when retry backoff is disabled' do
    let(:allow_retry_back_off) { false }

    it 'does not introduces backoff' do
      result = subject.call(
        retry_attempts: 1,
        queue_settings: queue_settings
      )

      expect(result).to eq(ms_to_seconds(retry_delay))


      result = subject.call(
        retry_attempts: retry_back_off_grace + 100,
        queue_settings: queue_settings
      )

      expect(result).to eq(ms_to_seconds(retry_delay))
    end

    context 'when jitter is set to 30' do
      let(:retry_jitter_ratio) { 30 }

      it 'stays between 70-100% of the calculated visibility timeout' do
        results = []
        1000.times do |i|
          result = subject.call(
            retry_attempts: i,
            queue_settings: queue_settings
          )

          expect(result).to be_between(ms_to_seconds(retry_delay * 0.7), ms_to_seconds(retry_delay))

          results << result
        end

        average = results.sum.to_f / results.size
        expect(average).to be_between(ms_to_seconds(retry_delay * 0.75), ms_to_seconds(retry_delay * 0.95))
      end
    end
  end

  context 'when retry backoff is enabled' do
    let(:allow_retry_back_off) { true }

    context 'when the retry_attempts is lower than the retry_back_off_grace' do
      it 'does not introduce backoff' do
        result = subject.call(
          retry_attempts: retry_back_off_grace - 1,
          queue_settings: queue_settings
        )

        expect(result).to eq(ms_to_seconds(retry_delay))
      end
    end

    context 'when the retry_attempts exceeds the retry_back_off_grace' do
      it 'introduces backoff' do
        retries_past_grace_period = 2

        result = subject.call(
          retry_attempts: retry_back_off_grace + retries_past_grace_period,
          queue_settings: queue_settings
        )

        expect(result).to eq(ms_to_seconds(retry_delay) * retries_past_grace_period)
      end
    end

    context 'when the visible_timeout exceeds the max_retry_delay' do
      it 'returns the max_retry_delay' do
        result = subject.call(
          retry_attempts: retry_back_off_grace + 100_000,
          queue_settings: queue_settings
        )

        expect(result).to eq(ms_to_seconds(max_retry_delay))
      end
    end

    context 'when the visible_timeout is bigger than max_timeout' do
      let(:max_retry_delay) { 50_000_000 }

      it 'the visible_timeout is set to max_timeout' do
        result = subject.call(
          retry_attempts: retry_back_off_grace + 100_000,
          queue_settings: queue_settings
        )

        expect(result).to eq(max_timeout)
      end
    end

    context 'when retry_back_off_weight is added' do
      let(:retry_back_off_weight) { 2 }
      let(:max_retry_delay) { 1_000_000 }

      it 'the backoff is multiplied' do
        retries_past_grace_period = 2

        result = subject.call(
          retry_attempts: retry_back_off_grace + retries_past_grace_period,
          queue_settings: queue_settings
        )

        expect(result).to eq(ms_to_seconds(retry_delay) * retries_past_grace_period * retry_back_off_weight)
      end
    end

    context 'when jitter is set to 30' do
      let(:retry_jitter_ratio) { 30 }

      it 'stays between 70-100% of the calculated visibility timeout' do
        results = []
        1000.times do |i|
          result = subject.call(
            retry_attempts: i,
            queue_settings: queue_settings
          )

          expect(result).to be_between(ms_to_seconds(retry_delay * 0.7), ms_to_seconds(retry_delay))

          results << result
        end

        average = results.sum.to_f / results.size
        expect(average).to be_between(ms_to_seconds(retry_delay * 0.75), ms_to_seconds(retry_delay * 0.95))
      end
    end

    context 'when exponential backoff is enabled' do
      let(:max_retry_delay) { 40_000_000 }
      let(:allow_exponential_back_off) { true }

      it 'grow the delay by 2 to the power of retries past grace period' do
        retries_past_grace_period = 10

        result = subject.call(
          retry_attempts: retry_back_off_grace + retries_past_grace_period,
          queue_settings: queue_settings
        )

        expect(result).to eq(ms_to_seconds(retry_delay) * 2 ** (retries_past_grace_period - 1))
      end

      it 'still caps at max delay' do
        retries_past_grace_period = 20

        result = subject.call(
          retry_attempts:       retry_back_off_grace + retries_past_grace_period,
          queue_settings: queue_settings
        )

        expect(result).to eq(ms_to_seconds(max_retry_delay))
      end
    end
  end

  def ms_to_seconds(value)
    value / 1000
  end
end
