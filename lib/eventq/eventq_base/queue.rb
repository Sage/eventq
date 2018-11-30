module EventQ
  class Queue
    attr_accessor :allow_retry
    attr_accessor :allow_retry_back_off
    attr_accessor :back_off_weight
    attr_accessor :dlq
    attr_accessor :max_retry_attempts
    attr_accessor :max_retry_delay
    attr_accessor :name
    attr_accessor :max_receive_count
    attr_accessor :require_signature
    attr_accessor :retry_delay
    attr_accessor :retry_back_off_grace

    def initialize
      @allow_retry = false
      # Default retry back off settings
      @allow_retry_back_off = false
      # Multiplier for the backoff retry in case retry_delay is too small
      @back_off_weight = 1
      # Default max receive count is 30
      @max_receive_count = 30
      # Default max retry attempts is 5
      @max_retry_attempts = 5
      # Default require signature to false
      @require_signature = false
      # Default retry delay is 30 seconds
      @retry_delay = 30000
      # This is the amount of times to allow retry to occurr before back off is implemented
      @retry_back_off_grace = 0
    end
  end
end
