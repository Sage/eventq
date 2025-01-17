module EventQ
  class NonceManager

    def self.configure(server:,timeout:10000,lifespan:3600, pool_size: 5, pool_timeout: 5)
      @server_url = server
      @timeout = timeout
      @lifespan = lifespan
      @pool_size = pool_size
      @pool_timeout = pool_timeout
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

    def self.pool_size
      @pool_size
    end

    def self.pool_timeout
      @pool_timeout
    end

    def self.lock(nonce)
      # act as if successfully locked if not nonce manager configured - makes it a no-op
      return true if not_configured?

      successfully_locked = false
      with_redis_connection do |conn|
        successfully_locked = conn.set(nonce, 1, ex: lifespan, nx: true)
      end

      if !successfully_locked
        EventQ.log(:info, "[#{self.class}] - Message has already been processed: #{nonce}")
      end

      successfully_locked
    end

    # if the message was successfully procesed, lock for another lifespan length
    # so it isn't reprocessed
    def self.complete(nonce)
      return true if not_configured?

      with_redis_connection do |conn|
        conn.expire(nonce, lifespan)
      end

      true
    end

    # if it failed, unlock immediately so that retries can kick in
    def self.failed(nonce)
      return true if not_configured?

      with_redis_connection do |conn|
        conn.del(nonce)
      end

      true
    end

    def self.reset
      @server_url = nil
      @timeout = nil
      @lifespan = nil
      @pool_size = nil
      @pool_timeout = nil
    end

    private

    def self.with_redis_connection
      redis_pool.with do |conn|
        yield conn
      end
    end

    def self.redis_pool
      @redis_pool ||= begin
        require 'connection_pool'
        require 'redis'

        ConnectionPool.new(size: @pool_size, timeout: @pool_timeout) do
          Redis.new(url: @server_url)
        end
      end
    end

    def self.not_configured?
      @server_url.nil? || @server_url.empty?
    end
  end
end
