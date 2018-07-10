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

      def connection_options
        {
            :host => @endpoint,
            :port => @port,
            :user => @user,
            :pass => @password,
            :ssl => @ssl,
            :read_timeout => 4,
            :heartbeat => 8,
            :continuation_timeout => 5000,
            :automatically_recover => true,
            :network_recovery_interval => 1,
            :recover_from_connection_close => true
        }
      end

      def get_connection
        if RUBY_PLATFORM =~ /java/
          conn = MarchHare.connect(connection_options)
        else
          conn = Bunny.new(connection_options)
        end

        conn.start
        return conn
      end

    end
  end
end
