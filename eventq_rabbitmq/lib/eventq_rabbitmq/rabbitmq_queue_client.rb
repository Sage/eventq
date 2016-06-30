module EventQ
  module RabbitMq
    class QueueClient

      def initialize(options = {})

        if options[:endpoint] == nil
          raise ':endpoint must be specified.'
        end

        @endpoint = options[:endpoint]

        @port = Integer(options[:port] || 5672)

        @user = options[:user] || 'guest'

        @password = options[:password] || 'guest'

        @ssl = options[:ssl] == true || false

      end

      def get_channel
        conn = Bunny.new(:host => @endpoint, :port => @port, :user => @user, :pass => @password, :ssl => @ssl)
        conn.start
        return conn.create_channel
      end

    end
  end
end
