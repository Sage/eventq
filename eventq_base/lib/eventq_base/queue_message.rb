module EventQ
  class QueueMessage
    extend ClassKit

    attr_accessor_type :retry_attempts, type: Integer
    attr_accessor_type :type, type: String
    attr_accessor_type :content
    attr_accessor_type :created, type: DateTime

    def initialize
      @retry_attempts = 0
      @created = DateTime.now
    end

  end
end
