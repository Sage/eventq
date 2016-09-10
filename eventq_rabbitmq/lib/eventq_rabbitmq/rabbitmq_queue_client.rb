module EventQ
  module RabbitMq
    class QueueClient

      GUEST = 'guest'.freeze

      def initialize(options = {})

        if options[:endpoint] == nil
          raise ':endpoint must be specified.'.freeze
        end

        @endpoint = options[:endpoint]

        @port = Integer(options[:port] || 5672)

        @user = options[:user] || GUEST

        @password = options[:password] || GUEST

        @ssl = options[:ssl] == true || false

      end

      def get_channel
        conn = Bunny.new(:host => @endpoint, :port => @port, :user => @user, :pass => @password, :ssl => @ssl)
        conn.start
        return conn.create_channel
      end

      def get_connection
        conn = Bunny.new(:host => @endpoint, :port => @port, :user => @user, :pass => @password, :ssl => @ssl)
        conn.start
        return conn
      end

    end
  end
end
