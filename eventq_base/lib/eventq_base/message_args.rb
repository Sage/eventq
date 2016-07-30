module EventQ
  class MessageArgs
    attr_reader :type
    attr_reader :retry_attempts
    attr_accessor :abort
    attr_accessor :drop

    def initialize(type, retry_attempts)
      @type = type
      @retry_attempts = retry_attempts
      @abort = false
      @drop = false
    end
  end
end