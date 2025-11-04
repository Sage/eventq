module EventQ
  class Queue
    attr_accessor :allow_retry
    attr_accessor :allow_retry_back_off
    attr_accessor :allow_exponential_back_off
    attr_accessor :dlq
    attr_accessor :max_retry_attempts
    attr_accessor :max_retry_delay
    attr_accessor :name
    attr_accessor :max_receive_count
    attr_accessor :require_signature
    attr_accessor :retry_delay
    attr_accessor :retry_back_off_grace
    attr_accessor :retry_back_off_weight
    attr_accessor :retry_jitter_ratio
    # Character delimiter between namespace and queue name.  Default = '-'
    attr_accessor :namespace_delimiter
    # Flag to control that the queue runs in isolation of auto creating the topic it belongs to
    attr_accessor :isolated

    def initialize
      @allow_retry = false
      # Default retry back off settings
      @allow_retry_back_off = false
      # Default exponential back off settings
      @allow_exponential_back_off = false
      # Default max receive count is 30
      @max_receive_count = 30
      # Default max retry attempts is 5
      @max_retry_attempts = 5
      # Default max retry_delay is 5000 (5seconds)
      @max_retry_delay = 5000
      # Default require signature to false
      @require_signature = false
      # Default retry delay is 30 seconds
      @retry_delay = 30000
      # This is the amount of times to allow retry to occurr before back off is implemented
      @retry_back_off_grace = 0
      # Multiplier for the backoff retry in case retry_delay is too small
      @retry_back_off_weight = 1
      # Ratio of how much jitter to apply to the retry delay
      @retry_jitter_ratio = 0
      @isolated = false
    end

    def log_settings
      EventQ.logger.info do
        <<~LOG.chomp
          [#{self.class}] - Settings: \
          name='#{@name}', \
          allow_retry='#{@allow_retry}', \
          allow_retry_back_off='#{@allow_retry_back_off}', \
          allow_exponential_back_off='#{@allow_exponential_back_off}', \
          dlq='#{@dlq}', \
          max_receive_count='#{@max_receive_count}', \
          max_retry_attempts='#{@max_retry_attempts}', \
          max_retry_delay='#{@max_retry_delay}', \
          retry_delay='#{@retry_delay}', \
          retry_back_off_grace='#{@retry_back_off_grace}', \
          retry_back_off_weight='#{@retry_back_off_weight}', \
          retry_jitter_ratio='#{@retry_jitter_ratio}', \
          require_signature='#{@require_signature}'
        LOG
      end
    end
  end
end
