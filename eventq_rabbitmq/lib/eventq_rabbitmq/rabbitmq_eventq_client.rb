module EventQ
  module RabbitMq
    class EventQClient

      def initialize(options={})

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'.freeze
        end

        @client = options[:client]
        @queue_manager = QueueManager.new
        @event_raised_exchange = EventRaisedExchange.new
        @serialization_manager = EventQ::SerializationProviders::Manager.new
        @signature_manager = EventQ::SignatureProviders::Manager.new
      end

      def raise_event(event_type, event)

        connection = @client.get_connection

        _event_type = EventQ.create_event_type(event_type)

        begin
        channel = connection.create_channel

        ex = @queue_manager.get_exchange(channel, @event_raised_exchange)

        qm = new_message
        qm.content = event
        qm.type = _event_type

        if EventQ::Configuration.signature_secret != nil
          provider = @signature_manager.get_provider(EventQ::Configuration.signature_provider)
          qm.signature = provider.write(message: qm, secret: EventQ::Configuration.signature_secret)
        end

        serialization_provider = @serialization_manager.get_provider(EventQ::Configuration.serialization_provider)

        message = serialization_provider.serialize(qm)

        ex.publish(message, :routing_key => _event_type)
        rescue => e

          channel.close
          connection.close
          raise e
        end

        channel.close
        connection.close

        EventQ.logger.debug "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type}."

        return true
      end

      def new_message
        EventQ::QueueMessage.new
      end

    end
  end
end

