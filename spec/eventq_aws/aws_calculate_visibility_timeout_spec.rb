require 'spec_helper'

RSpec.describe EventQ::Amazon::CalculateVisibilityTimeout do
  let(:max_timeout) { 43_200 }        # 43_200s (12h)
  let(:retry_delay) { 30_000 }        # 30s
  let(:max_retry_delay) { 100_000 }   # 100s
  let(:retry_back_off_grace) { 1000 } # iterations before the backoff grace quicks in
  let(:retry_back_off_weight) { 1 }   # backoff multiplier

  subject { described_class.new(max_timeout: max_timeout) }

  context 'when retry backoff is disabled' do
    let(:allow_retry_back_off) { false }

    it 'does not introduces backoff' do
      result = subject.call(
        retry_attempts:       1,
        queue_settings: {
          allow_retry_back_off:  allow_retry_back_off,
          max_retry_delay:       max_retry_delay,
          retry_back_off_grace:  retry_back_off_grace,
          retry_delay:           retry_delay,
          retry_back_off_weight: retry_back_off_weight
        }
      )

      expect(result).to eq(ms_to_seconds(retry_delay))


      result = subject.call(
        retry_attempts:       retry_back_off_grace + 100,
        queue_settings: {
          allow_retry_back_off:  allow_retry_back_off,
          max_retry_delay:       max_retry_delay,
          retry_back_off_grace:  retry_back_off_grace,
          retry_delay:           retry_delay,
          retry_back_off_weight: retry_back_off_weight
        }
      )

      expect(result).to eq(ms_to_seconds(retry_delay))
    end
  end

  context 'when retry backoff is enabled' do
    let(:allow_retry_back_off) { true }

    context 'when the retry_attempts is lower than the retry_back_off_grace' do
      it 'does not introduce backoff' do
        result = subject.call(
          retry_attempts:       retry_back_off_grace - 1,
          queue_settings: {
            allow_retry_back_off:  allow_retry_back_off,
            max_retry_delay:       max_retry_delay,
            retry_back_off_grace:  retry_back_off_grace,
            retry_delay:           retry_delay,
            retry_back_off_weight: retry_back_off_weight
          }
        )

        expect(result).to eq(ms_to_seconds(retry_delay))
      end
    end

    context 'when the retry_attempts exceeds the retry_back_off_grace' do
      it 'introduces backoff' do
        retries_past_grace_period = 2

        result = subject.call(
          retry_attempts:       retry_back_off_grace + retries_past_grace_period,
          queue_settings: {
            allow_retry_back_off:  allow_retry_back_off,
            max_retry_delay:       max_retry_delay,
            retry_back_off_grace:  retry_back_off_grace,
            retry_delay:           retry_delay,
            retry_back_off_weight: retry_back_off_weight
          }
        )

        expect(result).to eq(ms_to_seconds(retry_delay) * retries_past_grace_period)
      end
    end

    context 'when the visible_timeout exceeds the max_retry_delay' do
      it 'returns the max_retry_delay' do
        result = subject.call(
          retry_attempts:       retry_back_off_grace + 100_000,
          queue_settings: {
            allow_retry_back_off:  allow_retry_back_off,
            max_retry_delay:       max_retry_delay,
            retry_back_off_grace:  retry_back_off_grace,
            retry_delay:           retry_delay,
            retry_back_off_weight: retry_back_off_weight
          }
        )

        expect(result).to eq(ms_to_seconds(max_retry_delay))
      end
    end

    context 'when the visible_timeout is bigger than max_timeout' do
      it 'the visible_timeout is set to max_timeout' do
        result = subject.call(
          retry_attempts:       retry_back_off_grace + 100_000,
          queue_settings: {
            allow_retry_back_off:  allow_retry_back_off,
            max_retry_delay:       50_000_000,
            retry_back_off_grace:  retry_back_off_grace,
            retry_delay:           retry_delay,
            retry_back_off_weight: retry_back_off_weight
          }
        )

        expect(result).to eq(max_timeout)
      end
    end

    context 'when retry_back_off_weight is added' do
      it 'the backoff is multiplied' do
        retries_past_grace_period = 2
        retry_back_off_weight = 2

        result = subject.call(
          retry_attempts:       retry_back_off_grace + retries_past_grace_period,
          queue_settings: {
            allow_retry_back_off:  allow_retry_back_off,
            max_retry_delay:       1_000_000,
            retry_back_off_grace:  retry_back_off_grace,
            retry_delay:           retry_delay,
            retry_back_off_weight: retry_back_off_weight
          }
        )

        expect(result).to eq(ms_to_seconds(retry_delay) * retries_past_grace_period * retry_back_off_weight)
      end
    end

    context 'when exponential backoff is enabled' do
      let(:max_retry_delay) { 40_000_000 }
      let(:allow_exponential_back_off) { true }

      it 'grow the delay by 2 to the power of retries past grace period' do
        retries_past_grace_period = 10

        result = subject.call(
          retry_attempts:       retry_back_off_grace + retries_past_grace_period,
          queue_settings: {
            allow_retry_back_off:       allow_retry_back_off,
            allow_exponential_back_off: allow_exponential_back_off,
            max_retry_delay:            max_retry_delay,
            retry_back_off_grace:       retry_back_off_grace,
            retry_delay:                retry_delay,
            retry_back_off_weight:      retry_back_off_weight
          }
        )

        expect(result).to eq(ms_to_seconds(retry_delay) * 2 ** (retries_past_grace_period - 1))
      end

      it 'still caps at max delay' do
        retries_past_grace_period = 20

        result = subject.call(
          retry_attempts:       retry_back_off_grace + retries_past_grace_period,
          queue_settings: {
            allow_retry_back_off:       allow_retry_back_off,
            allow_exponential_back_off: allow_exponential_back_off,
            max_retry_delay:            max_retry_delay,
            retry_back_off_grace:       retry_back_off_grace,
            retry_delay:                retry_delay,
            retry_back_off_weight:      retry_back_off_weight
          }
        )

        expect(result).to eq(ms_to_seconds(max_retry_delay))
      end
    end
  end

  def ms_to_seconds(value)
    value / 1000
  end
end
