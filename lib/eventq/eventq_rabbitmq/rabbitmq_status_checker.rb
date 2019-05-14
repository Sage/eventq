module EventQ
  module RabbitMq
    class StatusChecker

      def initialize(client:, queue_manager:)

        if client == nil
          raise 'client  must be specified.'.freeze
        end

        @client = client

        if queue_manager == nil
          raise 'queue_manager  must be specified.'.freeze
        end

        @queue_manager = queue_manager

        @event_raised_exchange = EventRaisedExchange.new

      end

      def queue?(queue)

        outcome = true

        begin
          connection = @client.get_connection
          channel = connection.create_channel
          _queue_name = EventQ.create_queue_name(queue)
          channel.queue(_queue_name, :durable => true)
        rescue
          outcome = false
        ensure
          channel.close if channel
          connection.close if connection
        end

        outcome
      end

      def event_type?(event_type)

        outcome = true

        begin
          connection = @client.get_connection
          channel = connection.create_channel
          @queue_manager.get_exchange(channel, @event_raised_exchange)
        rescue
          outcome = false
        ensure
          channel.close if channel
          connection.close if connection
        end

        outcome
      end

    end
  end
end
