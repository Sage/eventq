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

        #get/create the queue
        q = channel.queue(queue.name, :durable => @durable)

        if queue.allow_retry
          retry_exchange = get_retry_exchange(channel, queue)
          subscriber_exchange = get_subscriber_exchange(channel, queue)

          retry_queue = get_retry_queue(channel, queue)
          retry_queue.bind(retry_exchange)

          q.bind(subscriber_exchange)
        end

        return q
      end

      def get_retry_exchange(channel, queue)
        return channel.fanout("#{queue.name}.r.ex")
      end

      def get_subscriber_exchange(channel, queue)
        return channel.fanout("#{queue.name}.ex")
      end

      def get_retry_queue(channel, queue)
        subscriber_exchange = get_subscriber_exchange(channel, queue)

        if queue.allow_retry_back_off == true

          EventQ.log(:debug, "[#{self.class}] - Requesting retry queue. x-dead-letter-exchange: #{subscriber_exchange.name} | x-message-ttl: #{queue.max_retry_delay}")

          return channel.queue("#{queue.name}.r", :durable => @durable, :arguments => { X_DEAD_LETTER_EXCHANGE => subscriber_exchange.name, X_MESSAGE_TTL => queue.max_retry_delay })

        else

          EventQ.log(:debug, "[#{self.class}] - Requesting retry queue. x-dead-letter-exchange: #{subscriber_exchange.name} | x-message-ttl: #{queue.retry_delay}")

          return channel.queue("#{queue.name}.r", :durable => @durable, :arguments => { X_DEAD_LETTER_EXCHANGE => subscriber_exchange.name, X_MESSAGE_TTL => queue.retry_delay })

        end

      end

      def get_exchange(channel, exchange)
        return channel.direct(exchange.name, :durable => @durable)
      end

    end
  end
end
