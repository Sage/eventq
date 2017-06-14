module EventQ
  class MessageArgs
    attr_reader :type
    attr_reader :retry_attempts
    attr_accessor :abort
    attr_accessor :drop
    attr_reader :context

    def initialize(type, retry_attempts, context = {})
      @type = type
      @retry_attempts = retry_attempts
      @abort = false
      @drop = false
      @context = context
    end
  end
end