module EventQ
  class NonceManager

    def self.configure(server:,timeout:10000,lifespan:3600000)
      @server_url = server
      @timeout = timeout
      @lifespan = lifespan
    end

    def self.server_url
      @server_url
    end

    def self.timeout
      @timeout
    end

    def self.lifespan
      @lifespan
    end

    def self.process(nonce, &block)

      if @server_url != nil

        process_with_nonce(nonce, block)

      else

        process_without_nonce(block)

      end

      return true

    end

    def self.process_with_nonce(nonce, block)
      @server = Redlock::Client.new([ @server_url ])
      @redis = Redis.new(url: @server_url)

      lock = @server.lock(nonce, @timeout)
      if lock == false
        raise NonceError.new("Message has already been processed: #{nonce}")
      end

      block.call

      @redis.expire(nonce, @lifespan)
    end

    def self.process_without_nonce(block)
      block.call
    end

    def self.reset
      @server_url = nil
      @timeout = nil
      @lifespan = nil
    end
  end
end