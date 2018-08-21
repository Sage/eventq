module EventQ
  module RabbitMq
    class QueueWorker
      include EventQ::WorkerId

      attr_accessor :is_running, :context

      def initialize
        @serialization_provider_manager = EventQ::SerializationProviders::Manager.new
        @signature_provider_manager = EventQ::SignatureProviders::Manager.new
      end

      def pre_process(context, options)
        manager = EventQ::RabbitMq::QueueManager.new
        manager.durable = options[:durable]
        options[:manager] = manager

        connection = options[:client].dup.get_connection
        options[:connection] = connection
      end

      # This method should not be called iteratively and will sit in a loop
      # The reason is because this uses a push notification from the subscribe mechanism to trigger the
      # block and will exit if you do not block.
      def thread_process_iteration(queue, options, block)
        manager = options[:manager]
        channel = options[:connection].create_channel
        channel.prefetch(1)

        q = manager.get_queue(channel, queue)
        retry_exchange = manager.get_retry_exchange(channel, queue)

        q.subscribe(:manual_ack => true, :block => false, :exclusive => false) do |delivery_info, properties, payload|
          begin
            tag_processing_thread
            process_message(payload, queue, channel, retry_exchange, delivery_info.delivery_tag, block)
          rescue => e
            EventQ.logger.error(
                "[#{self.class}] - An error occurred attempting to process a message. Error: #{e} | "\
"Backtrace: #{e.backtrace}"
            )
            context.call_on_error_block(error: e)
          ensure
            untag_processing_thread
          end
        end

        # we don't want to stop the subscribe process as it will not block.
        sleep 5 while context.running?

        if channel != nil && channel.open?
          channel.close
        end
      end

      def deserialize_message(payload)
        provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
        return provider.deserialize(payload)
      end

      def serialize_message(msg)
        provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
        return provider.serialize(msg)
      end

      def reject_message(channel, message, delivery_tag, retry_exchange, queue, abort)
        EventQ.logger.info("[#{self.class}] - Message rejected removing from queue.")
        # reject the message to remove from queue
        channel.reject(delivery_tag, false)

        # check if the message retry limit has been exceeded
        if message.retry_attempts >= queue.max_retry_attempts
          EventQ.logger.info("[#{self.class}] - Message retry attempt limit exceeded. Msg: #{serialize_message(message)}")

          context.call_on_retry_exceeded_block(message)
        # check if the message is allowed to be retried
        elsif queue.allow_retry
          message.retry_attempts += 1
          retry_attempts = message.retry_attempts - queue.retry_back_off_grace
          retry_attempts = 1 if retry_attempts < 1

          if queue.allow_retry_back_off == true
            message_ttl = retry_attempts * queue.retry_delay
            if (retry_attempts * queue.retry_delay) > queue.max_retry_delay
              EventQ.logger.debug { "[#{self.class}] - Max message back off retry delay reached." }
              message_ttl = queue.max_retry_delay
            end
          else
            message_ttl = queue.retry_delay
          end

          EventQ.logger.debug { "[#{self.class}] - Sending message for retry. Message TTL: #{message_ttl}" }
          retry_exchange.publish(serialize_message(message), :expiration => message_ttl)

          context.call_on_retry_block(message)
        end

        return true
      end

      def configure(options = {})
        options[:durable] ||= true
      end

      # Logic for the RabbitMq adapter when a message is accepted
      def acknowledge_message(channel, delivery_tag)
        channel.acknowledge(delivery_tag, false)
      end

      private

      def process_message(payload, queue, channel, retry_exchange, delivery_tag, block)
        message = deserialize_message(payload)
        retry_attempts = message.retry_attempts

        @signature_provider_manager.validate_signature(message: message, queue: queue)

        status, message_args = context.process_message(block, message, retry_attempts, [channel, delivery_tag])

        case status
          when :duplicate
            channel.acknowledge(delivery_tag, false)
          when :accepted
            # Acceptance was handled directly when QueueWorker#process_message was called
          when :reject
            reject_message(channel, message, delivery_tag, retry_exchange, queue, message_args.abort)
          else
            raise "Unrecognized status: #{status}"
        end
      end
    end
  end
end

