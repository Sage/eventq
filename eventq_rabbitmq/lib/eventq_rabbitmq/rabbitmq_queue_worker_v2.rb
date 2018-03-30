module EventQ
  module RabbitMq
    class QueueWorkerV2
      include EventQ::WorkerId

      attr_accessor :is_running

      def initialize
        @threads = []
        @forks = []
        @is_running = false

        @retry_exceeded_block = nil
        @on_retry_block = nil
        @on_error_block = nil
        @hash_helper = HashKit::Helper.new
        @serialization_provider_manager = EventQ::SerializationProviders::Manager.new
        @signature_provider_manager = EventQ::SignatureProviders::Manager.new
        @last_gc_flush = Time.now
        @gc_flush_interval = 10
      end

      def start(queue, options = {}, &block)

        EventQ.logger.info("[#{self.class}] - Preparing to start listening for messages.")

        configure(queue, options)

        raise "[#{self.class}] - Worker is already running." if running?

        if options[:client] == nil
          raise "[#{self.class}] - :client (QueueClient) must be specified."
        end

        EventQ.logger.info("[#{self.class}] - Listening for messages.")
        EventQ.logger.debug do
          "[#{self.class} #start] - Listening for messages on queue: #{EventQ.create_queue_name(queue.name)}"
        end

        @forks = []

        if @fork_count > 1
          Thread.new do
            @fork_count.times do
              pid = fork do
                start_process(options, queue, block)
              end
              @forks.push(pid)
            end
            @forks.each { |pid| Process.wait(pid) }
          end
        else
          start_process(options, queue, block)
        end
      end

      def start_process(options, queue, block)
        @is_running = true

        %w'INT TERM'.each do |sig|
          Signal.trap(sig) {
            stop
            exit
          }
        end

        if !options.key?(:durable)
          options[:durable] = true
        end

        client = options[:client]
        manager = EventQ::RabbitMq::QueueManager.new
        manager.durable = options[:durable]
        @connection = client.get_connection

        @threads = []

        # loop through each thread count
        @thread_count.times do
          channel = @connection.create_channel

          q = manager.get_queue(channel, queue)
          retry_exchange = manager.get_retry_exchange(channel, queue)

          q.subscribe(:manual_ack => true, :consumer_tag => SecureRandom.uuid) do |delivery_info, properties, payload|
            begin
              tag_processing_thread
              process_message(payload, queue, channel, retry_exchange, delivery_info.delivery_tag, block)
            rescue => e
              EventQ.logger.error(
                "[#{self.class}] - An error occurred attempting to process a message. Error: #{e} | "\
"Backtrace: #{e.backtrace}"
              )
              call_on_error_block(error: e)
            ensure
              untag_processing_thread
            end
          end
        end

        if options.key?(:wait) && options[:wait] == true || options[:fork_count] > 1
          while running? do
            sleep 5
          end
        end

        return true
      end

      def call_on_error_block(error:, message: nil)
        if @on_error_block
          EventQ.logger.debug { "[#{self.class}] - Executing on_error block." }
          begin
            @on_error_block.call(error, message)
          rescue => e
            EventQ.logger.error("[#{self.class}] - An error occurred executing the on_error block. Error: #{e}")
          end
        else
          EventQ.logger.debug { "[#{self.class}] - No on_error block specified to execute." }
        end
      end

      def stop
        EventQ.logger.info { "[#{self.class}] - Stopping..." }
        @is_running = false

        if @connection != nil
          begin
            @connection.close if @connection.open?
          rescue Timeout::Error
            EventQ.logger.error { 'Timeout occurred closing connection.' }
          end
        end
        return true
      end

      def on_retry_exceeded(&block)
        @retry_exceeded_block = block
        return nil
      end

      def on_retry(&block)
        @on_retry_block = block
        return nil
      end

      def on_error(&block)
        @on_error_block = block
        return nil
      end

      def running?
        return @is_running
      end

      def deserialize_message(payload)
        provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
        return provider.deserialize(payload)
      end

      def serialize_message(msg)
        provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
        return provider.serialize(msg)
      end

      def call_on_retry_exceeded_block(message)
        if @retry_exceeded_block != nil
          EventQ.logger.debug { "[#{self.class}] - Executing on_retry_exceeded block." }
          begin
            @retry_exceeded_block.call(message)
          rescue => e
            EventQ.logger.error("[#{self.class}] - An error occurred executing the on_retry_exceeded block. Error: #{e}")
          end
        else
          EventQ.logger.debug { "[#{self.class}] - No on_retry_exceeded block specified." }
        end
      end

      def call_on_retry_block(message)
        if @on_retry_block
          EventQ.logger.debug { "[#{self.class}] - Executing on_retry block." }
          begin
            @on_retry_block.call(message, abort)
          rescue => e
            EventQ.logger.error("[#{self.class}] - An error occurred executing the on_retry block. Error: #{e}")
          end
        else
          EventQ.logger.debug { "[#{self.class}] - No on_retry block specified." }
        end
      end

      def reject_message(channel, message, delivery_tag, retry_exchange, queue, abort)
        EventQ.logger.info("[#{self.class}] - Message rejected removing from queue.")
        # reject the message to remove from queue
        channel.reject(delivery_tag, false)

        # check if the message retry limit has been exceeded
        if message.retry_attempts >= queue.max_retry_attempts

          EventQ.logger.info("[#{self.class}] - Message retry attempt limit exceeded. Msg: #{serialize_message(message)}")

          call_on_retry_exceeded_block(message)

        # check if the message is allowed to be retried
        elsif queue.allow_retry
          EventQ.logger.debug { "[#{self.class}] - Incrementing retry attempts count." }
          message.retry_attempts += 1

          if queue.allow_retry_back_off == true
            EventQ.logger.debug do
              "[#{self.class}] - Calculating message back off retry delay. "\
"Attempts: #{message.retry_attempts} * Retry Delay: #{queue.retry_delay}"
            end
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

          call_on_retry_block(message)
        end

        return true
      end

      def configure(queue, options = {})
        @queue = queue

        # default thread count
        @thread_count = 1
        if options.key?(:thread_count)
          @thread_count = options[:thread_count]
        end

        @fork_count = 1
        if options.key?(:fork_count)
          @fork_count = options[:fork_count]
        end

        EventQ.logger.info(
          "[#{self.class}] - Configuring. Process Count: #{@fork_count} | Thread Count: #{@thread_count} | "\
"Interval Sleep: #{@sleep}."
        )

        return true
      end

      private

      def process_message(payload, queue, channel, retry_exchange, delivery_tag, block)
        abort = false
        error = false
        message = deserialize_message(payload)

        EventQ.logger.info("[#{self.class}] - Message received. Retry Attempts: #{message.retry_attempts}")

        @signature_provider_manager.validate_signature(message: message, queue: queue)

        message_args = EventQ::MessageArgs.new(type: message.type,
                                               retry_attempts: message.retry_attempts,
                                               context: message.context,
                                               content_type: message.content_type)

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
          EventQ.logger.error do
            "[#{self.class}] - An unhandled error happened attempting to process a queue message. "\
"Error: #{e} | Backtrace: #{e.backtrace}"
          end
          error = true
          call_on_error_block(error: e, message: message)
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

