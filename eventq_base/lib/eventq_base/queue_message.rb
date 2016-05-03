class QueueMessage
  attr_accessor :retry_attempts
  attr_accessor :type
  attr_accessor :content
  attr_accessor :created

  def initialize
    @retry_attempts = 0
    @created = DateTime.now
  end
end