module EventQ
  module RabbitMq
    class QueueManager

      X_DEAD_LETTER_EXCHANGE = 'x-dead-letter-exchange'.freeze
      X_MESSAGE_TTL = 'x-message-ttl'.freeze

      attr_accessor :durable

      def initialize
        @event_raised_exchange = EventQ::EventRaisedExchange.new
        @durable = true
      end

      def get_queue(channel, queue)

        _queue_name = EventQ.create_queue_name(queue.name)

        # get/create the queue
        q = channel.queue(_queue_name, :durable => @durable)

        subscriber_exchange = get_subscriber_exchange(channel, queue)

        if queue.allow_retry
          retry_exchange = get_retry_exchange(channel, queue)
          retry_queue = get_retry_queue(channel, queue)
          retry_queue.bind(retry_exchange)
        end

        q.bind(subscriber_exchange)

        return q
      end

      def pop_message(queue:)
        headers, properties, payload = queue.pop({ :manual_ack => true, :block => true })
        if headers == nil
          return [nil,nil]
        end
        [headers.delivery_tag, payload]
      end

      def get_queue_exchange(channel, queue)
        _exchange_name = EventQ.create_exchange_name(queue.name)
        channel.fanout("#{_exchange_name}.ex")
      end

      def get_retry_exchange(channel, queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        return channel.fanout("#{_queue_name}.r.ex")
      end

      def get_subscriber_exchange(channel, queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        return channel.fanout("#{_queue_name}.ex")
      end

      def get_delay_exchange(channel, queue, delay)
        _queue_name = EventQ.create_queue_name(queue.name)
        channel.direct("#{_queue_name}.#{delay}.d.ex")
      end

      def get_retry_queue(channel, queue)
        subscriber_exchange = get_subscriber_exchange(channel, queue)

        _queue_name = EventQ.create_queue_name(queue.name)

        if queue.allow_retry_back_off == true

          EventQ.logger.debug { "[#{self.class}] - Requesting retry queue. x-dead-letter-exchange: #{subscriber_exchange.name} | x-message-ttl: #{queue.max_retry_delay}" }

          return channel.queue("#{_queue_name}.r", :durable => @durable, :arguments => { X_DEAD_LETTER_EXCHANGE => subscriber_exchange.name, X_MESSAGE_TTL => queue.max_retry_delay })

        else

          EventQ.logger.debug { "[#{self.class}] - Requesting retry queue. x-dead-letter-exchange: #{subscriber_exchange.name} | x-message-ttl: #{queue.retry_delay}" }

          return channel.queue("#{_queue_name}.r", :durable => @durable, :arguments => { X_DEAD_LETTER_EXCHANGE => subscriber_exchange.name, X_MESSAGE_TTL => queue.retry_delay })

        end

      end

      def create_delay_queue(channel, queue, dlx_name, delay=0)
        queue_name = EventQ.create_queue_name(queue.name)
        channel.queue("#{queue_name}.#{delay}.delay", durable: @durable,
                      arguments: { X_DEAD_LETTER_EXCHANGE => dlx_name, X_MESSAGE_TTL => delay * 1000 })
      end

      def get_exchange(channel, exchange)
        _exchange_name = EventQ.create_exchange_name(exchange.name)
        return channel.direct(_exchange_name, :durable => @durable)
      end
    end
  end
end
