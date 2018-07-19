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
        #reject the message to remove from queue
        channel.reject(delivery_tag, false)

        #check if the message retry limit has been exceeded
        if message.retry_attempts >= queue.max_retry_attempts

          EventQ.logger.info("[#{self.class}] - Message retry attempt limit exceeded. Msg: #{serialize_message(message)}")

          context.call_on_retry_exceeded_block(message)

        #check if the message is allowed to be retried
        elsif queue.allow_retry

          EventQ.logger.debug { "[#{self.class}] - Incrementing retry attempts count." }
          message.retry_attempts += 1

          if queue.allow_retry_back_off == true
            EventQ.logger.debug { "[#{self.class}] - Calculating message back off retry delay. Attempts: #{message.retry_attempts} * Retry Delay: #{queue.retry_delay}" }
            message_ttl = message.retry_attempts * queue.retry_delay
            if (message.retry_attempts * queue.retry_delay) > queue.max_retry_delay
              EventQ.logger.debug { "[#{self.class}] - Max message back off retry delay reached." }
              message_ttl = queue.max_retry_delay
            end
          else
            EventQ.logger.debug { "[#{self.class}] - Setting fixed retry delay for message." }
            message_ttl = queue.retry_delay
          end

          EventQ.logger.debug { "[#{self.class}] - Sending message for retry. Message TTL: #{message_ttl}" }
          retry_exchange.publish(serialize_message(message), :expiration => message_ttl)
          EventQ.logger.debug { "[#{self.class}] - Published message to retry exchange." }

          context.call_on_retry_block(message)

        end

        return true

      end

      def configure(options = {})
        options[:durable] ||= true
      end

      private

      def process_message(payload, queue, channel, retry_exchange, delivery_tag, block)
        abort = false
        error = false
        message = deserialize_message(payload)

        EventQ.logger.info("[#{self.class}] - Message received. Retry Attempts: #{message.retry_attempts}")

        @signature_provider_manager.validate_signature(message: message, queue: queue)

        message_args = EventQ::MessageArgs.new(
          type: message.type,
          retry_attempts: message.retry_attempts,
          context: message.context,
          content_type: message.content_type,
          id: message.id,
          sent: message.created
        )

        if(!EventQ::NonceManager.is_allowed?(message.id))
          EventQ.logger.info("[#{self.class}] - Duplicate Message received. Dropping message.")
          channel.acknowledge(delivery_tag, false)
          return false
        end

        # begin worker block for queue message
        begin
          block.call(message.content, message_args)

          if message_args.abort == true
            abort = true
            EventQ.logger.info("[#{self.class}] - Message aborted.")
          else
            # accept the message as processed
            channel.acknowledge(delivery_tag, false)
            EventQ.logger.info("[#{self.class}] - Message acknowledged.")
          end

        rescue => e
          EventQ.logger.error("[#{self.class}] - An unhandled error happened attempting to process a queue message. Error: #{e} | Backtrace: #{e.backtrace}")
          error = true
          context.call_on_error_block(error: e, message: message)
        end

        if error || abort
          EventQ::NonceManager.failed(message.id)
          reject_message(channel, message, delivery_tag, retry_exchange, queue, abort)
        else
          EventQ::NonceManager.complete(message.id)
        end
      end
    end
  end
end

