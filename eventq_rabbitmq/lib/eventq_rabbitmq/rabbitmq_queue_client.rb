module EventQ
  module RabbitMq
    class QueueClient

      def initialize

        @endpoint = ENV['MQ_ENDPOINT'] || 'localhost'

        @port = Integer(ENV['MQ_PORT'] || 5672)

        @user = ENV['MQ_USER'] || 'guest'

        @password = ENV['MQ_PASSWORD'] || 'guest'

        @ssl = ENV['MQ_SSL'] == 'true' || false

      end

      def get_channel
        conn = Bunny.new(:host => @endpoint, :port => @port, :user => @user, :pass => @password, :ssl => @ssl)
        conn.start
        return conn.create_channel
      end

    end
  end
end
