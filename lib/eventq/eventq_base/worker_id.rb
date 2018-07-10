module EventQ
  # Module to be used by concrete worker classes to tag each thread working on a message
  # Allows to be used in custom logging to track group of log messages per queue message processing.
  module WorkerId
    def tag_processing_thread
      Thread.current[key_name] = SecureRandom.uuid
    end

    def untag_processing_thread
      Thread.current[key_name] = nil
    end

    private

    def key_name
      'worker_id'.freeze
    end

  end
end
