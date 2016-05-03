class Queue
  attr_accessor :name
  attr_accessor :allow_retry
  attr_accessor :retry_delay
  attr_accessor :max_retry_attempts

  def initialize
    @allow_retry = false
    #default retry delay is 30 seconds
    @retry_delay = 30000
    #default max retry attempts is 5
    @max_retry_attempts = 5
  end
end