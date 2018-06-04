require 'aws-sdk'

module EventQ
  module Amazon
    class QueueWorkerV2
      include EventQ::WorkerId

      APPROXIMATE_RECEIVE_COUNT = 'ApproximateReceiveCount'.freeze
      MESSAGE = 'Message'.freeze

      attr_accessor :is_running

      def initialize
        @forks = []
        @is_running = false

        @on_retry_exceeded_block = nil
        @on_retry_block = nil
        @on_error_block = nil

        @hash_helper = HashKit::Helper.new
        @serialization_provider_manager = EventQ::SerializationProviders::Manager.new
        @signature_provider_manager = EventQ::SignatureProviders::Manager.new

        @queue_poll_wait = 10
      end

      def start(queue, options = {}, &block)

        EventQ.logger.info("[#{self.class}] - Preparing to start listening for messages.")

        configure(queue, options)

        if options[:client] == nil
          raise "[#{self.class}] - :client (QueueClient) must be specified."
        end

        raise "[#{self.class}] - Worker is already running." if running?

        client = options[:client]
        EventQ.logger.debug do
          "[#{self.class} #start] - Listening for messages on queue: #{queue.name}, Queue Url: #{client.get_queue_url(queue)}, Queue arn: #{client.get_queue_arn(queue)}"
        end

        EventQ.logger.info("[#{self.class}] - Listening for messages.")

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

        return true
      end

      def start_process(options, queue, block)

        %w'INT TERM'.each do |sig|
          Signal.trap(sig) {
            stop
            exit
          }
        end

        @is_running = true

        Thread.new do
          client = options[:client]
          manager = EventQ::Amazon::QueueManager.new({ client: client })

          queue_url = manager.get_queue(queue)
          poller = Aws::SQS::QueuePoller.new(queue_url, attribute_names: [APPROXIMATE_RECEIVE_COUNT])

          poller.poll(skip_delete: true) do |msg, stats|
            begin
              tag_processing_thread
              process_message(msg, poller, queue, block)
            rescue => e
              EventQ.logger.error do
                "[#{self.class}] - An unhandled error occurred. Error: #{e} | Backtrace: #{e.backtrace}"
              end
              call_on_error_block(error: e)
            ensure
              untag_processing_thread
            end
          end
        end

        if (options.key?(:wait) && options[:wait] == true) || (options.key?(:fork_count) && options[:fork_count] > 1)
          while running? do
            sleep 5
          end
        end
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

      def call_on_retry_exceeded_block(message)
        if @on_retry_exceeded_block != nil
          EventQ.logger.debug { "[#{self.class}] - Executing on_retry_exceeded block." }
          begin
            @on_retry_exceeded_block.call(message)
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

      def stop
        EventQ.logger.info("[#{self.class}] - Stopping.")
        @is_running = false
        return true
      end

      def on_retry_exceeded(&block)
        @retry_exceeded_block = block
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

      private

      def process_message(msg, poller, queue, block)
        retry_attempts = msg.attributes[APPROXIMATE_RECEIVE_COUNT].to_i - 1

        # deserialize the message payload
        payload = JSON.load(msg.body)
        message = deserialize_message(payload[MESSAGE])

        message_args = EventQ::MessageArgs.new(
          type: message.type,
          retry_attempts: retry_attempts,
          context: message.context,
          content_type: message.content_type,
          id: message.id,
          sent: message.created
        )

        EventQ.logger.info("[#{self.class}] - Message received. Retry Attempts: #{retry_attempts}")

        @signature_provider_manager.validate_signature(message: message, queue: queue)

        if(!EventQ::NonceManager.is_allowed?(message.id))
          EventQ.logger.info("[#{self.class}] - Duplicate Message received. Ignoring message.")
          return false
        end

        # begin worker block for queue message
        begin

          block.call(message.content, message_args)

          if message_args.abort == true
            EventQ.logger.info("[#{self.class}] - Message aborted.")
          else
            # accept the message as processed
            poller.delete_message(msg)
            EventQ.logger.info("[#{self.class}] - Message acknowledged.")
          end

        rescue => e
          EventQ.logger.error("[#{self.class}] - An unhandled error happened while attempting to process a queue message. Error: #{e} | Backtrace: #{e.backtrace}")
          error = true
          call_on_error_block(error: e, message: message)
        end

        if message_args.abort || error
          EventQ::NonceManager.failed(message.id)
          reject_message(queue, poller, msg, retry_attempts, message, message_args.abort)
        else
          EventQ::NonceManager.complete(message.id)
        end

        return true
      end

      def reject_message(queue, poller, msg, retry_attempts, message, abort)
        if abort || !queue.allow_retry || retry_attempts >= queue.max_retry_attempts
          EventQ.logger.info("[#{self.class}] - Message rejected removing from queue. Message: #{serialize_message(message)}")

          # remove the message from the queue so that it does not get retried again
          poller.delete_message(msg)

          if retry_attempts >= queue.max_retry_attempts
            EventQ.logger.info("[#{self.class}] - Message retry attempt limit exceeded.")
            call_on_retry_exceeded_block(message)
          end
        elsif queue.allow_retry
          retry_attempts += 1

          EventQ.logger.info("[#{self.class}] - Message rejected requesting retry. Attempts: #{retry_attempts}")

          if queue.allow_retry_back_off == true
            EventQ.logger.debug { "[#{self.class}] - Calculating message back off retry delay. Attempts: #{retry_attempts} * Delay: #{queue.retry_delay}" }
            visibility_timeout = (queue.retry_delay * retry_attempts) / 1000
            if visibility_timeout > (queue.max_retry_delay / 1000)
              EventQ.logger.debug { "[#{self.class}] - Max message back off retry delay reached." }
              visibility_timeout = queue.max_retry_delay / 1000
            end
          else
            EventQ.logger.debug { "[#{self.class}] - Setting fixed retry delay for message." }
            visibility_timeout = queue.retry_delay / 1000
          end

          if visibility_timeout > 43200
            EventQ.logger.debug { "[#{self.class}] - AWS max visibility timeout of 12 hours has been exceeded. Setting message retry delay to 12 hours." }
            visibility_timeout = 43200
          end

          EventQ.logger.debug { "[#{self.class}] - Sending message for retry. Message TTL: #{visibility_timeout}" }
          poller.change_message_visibility_timeout(msg, visibility_timeout)

          call_on_retry_block(message)
        end

      end

      def configure(queue, options = {})
        @queue = queue

        if options.key?(:thread_count)
          EventQ.logger.warn("[#{self.class}] - :thread_count is deprecated.")
        end

        if options.key?(:sleep)
          EventQ.logger.warn("[#{self.class}] - :sleep is deprecated.")
        end

        @fork_count = 1
        if options.key?(:fork_count)
          @fork_count = options[:fork_count]
        end

        EventQ.logger.info("[#{self.class}] - Configuring. Process Count: #{@fork_count}.")

        return true
      end
    end
  end
end
