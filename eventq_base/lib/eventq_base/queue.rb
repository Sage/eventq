module EventQ
  class Queue
    attr_accessor :name
    attr_accessor :allow_retry
    attr_accessor :retry_delay
    attr_accessor :max_retry_attempts
    attr_accessor :allow_retry_back_off
    attr_accessor :max_retry_delay
    attr_accessor :require_signature

    def initialize
      @allow_retry = false
      #default retry delay is 30 seconds
      @retry_delay = 30000
      #default max retry attempts is 5
      @max_retry_attempts = 5
      #default retry back off settings
      @allow_retry_back_off = false
      #default require signature to false
      @require_signature = false
    end
  end
end
