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

        #this array is used to record known event types
        @known_event_types = []
      end

      def registered?(event_type)
        @known_event_types.include?(event_type)
      end

      def register_event(event_type)
        if registered?(event_type)
          return true
        end

        @known_event_types << event_type
        true
      end

      def raise_event(event_type, event)

        register_event(event_type)

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

          EventQ.logger.debug "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type}."
        ensure
          channel.close
          connection.close
        end

        return true
      end

      def raise_event_in_queue(event_type, event, queue, delay)

        register_event(event_type)

        connection = @client.get_connection

        _event_type = EventQ.create_event_type(event_type)

        begin
          channel = connection.create_channel

          ex = @queue_manager.get_exchange(channel, @event_raised_exchange)

          delay_exchange = @queue_manager.get_delay_exchange(channel, queue)

          delay_queue = @queue_manager.create_delay_queue(channel, queue, ex.name, delay)
          delay_queue.bind(delay_exchange)

          _queue_name = EventQ.create_queue_name(queue.name)

          q = channel.queue(_queue_name, :durable => @durable)
          q.bind(ex)

          qm = new_message
          qm.content = event
          qm.type = _event_type

          if EventQ::Configuration.signature_secret != nil
            provider = @signature_manager.get_provider(EventQ::Configuration.signature_provider)
            qm.signature = provider.write(message: qm, secret: EventQ::Configuration.signature_secret)
          end

          serialization_provider = @serialization_manager.get_provider(EventQ::Configuration.serialization_provider)

          message = serialization_provider.serialize(qm)

          delay_exchange.publish(message, :routing_key => _event_type)

          EventQ.logger.debug "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type} | Delay: #{delay}."
        ensure
          channel.close
          connection.close
        end

        return true
      end

      def new_message
        EventQ::QueueMessage.new
      end

    end
  end
end

