module EventQ
  module RabbitMq
    # Implements a general interface to raise an event
    # EventQ::Amazon::EventQClient is the sister-class which does the same for AWS
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

      def publish(topic:, event:, context: {})
        raise_event(topic, event, context)
      end

      def raise_event(event_type, event, context = {})
        register_event(event_type)

        _event_type = EventQ.create_event_type(event_type)

        with_connection do |channel|
          exchange = @queue_manager.get_exchange(channel, @event_raised_exchange)

          message = serialized_message(_event_type, event, context)

          exchange.publish(message, routing_key: _event_type)

          EventQ.logger.debug do
            "[#{self.class}] - Raised event to Exchange: #{_event_type} | Message: #{message}."
          end
        end
      end

      def raise_event_in_queue(event_type, event, queue, delay, context = {})
        register_event(event_type)

        _event_type = EventQ.create_event_type(event_type)

        with_connection do |channel|
          exchange = @queue_manager.get_queue_exchange(channel, queue)

          delay_exchange = @queue_manager.get_delay_exchange(channel, queue, delay)

          delay_queue = @queue_manager.create_delay_queue(channel, queue, exchange.name, delay)
          delay_queue.bind(delay_exchange, routing_key: _event_type)

          _queue_name = EventQ.create_queue_name(queue.name)

          q = channel.queue(_queue_name, durable: @queue_manager.durable)
          q.bind(exchange, routing_key: _event_type)

          message = serialized_message(_event_type, event, context)

          delay_exchange.publish(message, routing_key: _event_type)

          EventQ.logger.debug do
            "[#{self.class}] - Raised event to Exchange: #{_event_type} | Message: #{message} | Delay: #{delay}."
          end
        end
      end

      def new_message
        EventQ::QueueMessage.new
      end

      private

      def with_connection
        connection = @client.get_connection

        begin
          channel = connection.create_channel

          yield(channel)

        ensure
          channel&.close
          connection.close
        end

        true
      end

      def serialized_message(event_type, event, context)
        qm = new_message
        qm.content = event
        qm.type = event_type
        qm.context = context
        qm.content_type = event.class.to_s

        if EventQ::Configuration.signature_secret != nil
          provider = @signature_manager.get_provider(EventQ::Configuration.signature_provider)
          qm.signature = provider.write(message: qm, secret: EventQ::Configuration.signature_secret)
        end

        serialization_provider = @serialization_manager.get_provider(EventQ::Configuration.serialization_provider)

        serialization_provider.serialize(qm)
      end
    end
  end
end

