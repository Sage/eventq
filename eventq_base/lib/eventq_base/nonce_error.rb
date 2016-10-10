module EventQ
  class NonceError < StandardError
    def initialize(message = 'Message has already been processed.')
      super(message)
    end
  end
end