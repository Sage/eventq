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

    def self.is_allowed?(nonce)
      if @server_url == nil
        return true
      end

      lock = Redlock::Client.new([ @server_url ]).lock(nonce, @timeout)
      if lock == false
        EventQ.log(:info, "Message has already been processed: #{nonce}")
        return false
      end

      return true
    end

    def self.complete(nonce)
      if @server_url != nil
        Redis.new(url: @server_url).expire(nonce, @lifespan)
      end
      return true
    end

    def self.failed(nonce)
      if @server_url != nil
        Redis.new(url: @server_url).del(nonce)
      end
      return true
    end

    def self.reset
      @server_url = nil
      @timeout = nil
      @lifespan = nil
    end
  end
end