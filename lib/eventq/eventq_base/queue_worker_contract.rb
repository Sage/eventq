module EventQ
  # Contract class for queue workers
  class QueueWorkerContract

    def start(queue, options = {}, &block)

    end

    def stop

    end

    def on_retry_exceeded(&block)

    end

    def running?

    end

  end
end

