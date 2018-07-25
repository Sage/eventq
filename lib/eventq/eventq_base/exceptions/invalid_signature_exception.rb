module EventQ
  module Exceptions
    class InvalidSignatureException < StandardError
      def initialize(message = "Invalid message signature.")
        super(message)
      end
    end
  end
end