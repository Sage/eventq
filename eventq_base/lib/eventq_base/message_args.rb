module EventQ
  class MessageArgs
    attr_reader :type
    attr_reader :retry_attempts
    attr_accessor :abort

    def initialize(type, retry_attempts)
      @type = type
      @retry_attempts = retry_attempts
      @abort = false
    end
  end
end