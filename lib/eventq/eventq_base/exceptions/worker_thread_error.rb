module EventQ
  module Exceptions
    # General thread error that signifies a thread about to shutdown.
    class WorkerThreadError < StandardError
      def initialize(message = 'Worker thread error')
        super(message)
      end
    end
  end
end
