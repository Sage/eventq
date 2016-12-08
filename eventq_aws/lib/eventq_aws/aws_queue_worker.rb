module EventQ
  module Amazon
    class QueueWorker
      include EventQ::WorkerId

      APPROXIMATE_RECEIVE_COUNT = 'ApproximateReceiveCount'.freeze
      MESSAGE = 'Message'.freeze

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

        @last_gc_flush = Time.now
        @gc_flush_interval = 10

        @queue_poll_wait = 10
      end

      def start(queue, options = {}, &block)

        EventQ.log(:info, "[#{self.class}] - Preparing to start listening for messages.")

        configure(queue, options)

        if options[:client] == nil
          raise "[#{self.class}] - :client (QueueClient) must be specified."
        end

        raise "[#{self.class}] - Worker is already running." if running?

        EventQ.log(:info, "[#{self.class}] - Listening for messages.")

        @forks = []

        if @fork_count > 1
          @fork_count.times do
            pid = fork do
              start_process(options, queue, block)
            end
            @forks.push(pid)
          end

          if options.key?(:wait) && options[:wait] == true
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
        @threads = []

        #loop through each thread count
        @thread_count.times do
          thr = Thread.new do

            client = options[:client]
            manager = EventQ::Amazon::QueueManager.new({ client: client })

            #begin the queue loop for this thread
            while true do

              #check if the worker is still allowed to run and break out of thread loop if not
              if !@is_running
                break
              end

              has_message_received = thread_process_iteration(client, manager, queue, block)

              gc_flush

              if !has_message_received
                EventQ.log(:debug, "[#{self.class}] - No message received.")
                if @sleep > 0
                  EventQ.log(:debug, "[#{self.class}] - Sleeping for #{@sleep} seconds")
                  sleep(@sleep)
                end
              end

            end

          end
          @threads.push(thr)

        end

        if options.key?(:wait) && options[:wait] == true
          @threads.each { |thr| thr.join }
        end

      end

      def gc_flush
        if Time.now - last_gc_flush > @gc_flush_interval
          GC.start
          @last_gc_flush = Time.now
        end
      end

      def last_gc_flush
        @last_gc_flush
      end

      def thread_process_iteration(client, manager, queue, block)
        #get the queue
        q = manager.get_queue(queue)

        received = false

        begin

          #request a message from the queue
          response = client.sqs.receive_message({
                                                    queue_url: q,
                                                    max_number_of_messages: 1,
                                                    wait_time_seconds: @queue_poll_wait,
                                                    attribute_names: [APPROXIMATE_RECEIVE_COUNT]
                                                })

          #check that a message was received
          if response.messages.length > 0
            received = true
            begin
              tag_processing_thread
              process_message(response, client, queue, q, block)
            ensure
              untag_processing_thread
            end

          end

        rescue => e
          EventQ.log(:error, "[#{self.class}] - An unhandled error occurred. Error: #{e} | Backtrace: #{e.backtrace}")

          if @on_error_block
            EventQ.log(:debug, "[#{self.class}] - Executing on error block.")
            begin
              @on_error_block.call(e, message)
            rescue => e2
              EventQ.log(:error, "[#{self.class}] - An error occurred executing the on error block. Error: #{e2}")
            end
          end
        end

        return received
      end

      def stop
        EventQ.log(:info, "[#{self.class}] - Stopping.")
        @is_running = false
        @threads.each { |thr| thr.join }
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

      def process_message(response, client, queue, q, block)
        msg = response.messages[0]
        retry_attempts = msg.attributes[APPROXIMATE_RECEIVE_COUNT].to_i - 1

        #deserialize the message payload
        payload = JSON.load(msg.body)
        message = deserialize_message(payload[MESSAGE])

        message_args = EventQ::MessageArgs.new(message.type, retry_attempts)

        EventQ.log(:info, "[#{self.class}] - Message received. Retry Attempts: #{retry_attempts}")

        if(!EventQ::NonceManager.is_allowed?(message.id))
          EventQ.log(:info, "[#{self.class}] - Duplicate Message received. Dropping message.")
          client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })
          return false
        end

        #begin worker block for queue message
        begin

          block.call(message.content, message_args)

          if message_args.abort == true
            EventQ.log(:info, "[#{self.class}] - Message aborted.")
          else
            #accept the message as processed
            client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })
            EventQ.log(:info, "[#{self.class}] - Message acknowledged.")
          end

        rescue => e
          EventQ.log(:error, "[#{self.class}] - An unhandled error happened while attempting to process a queue message. Error: #{e} | Backtrace: #{e.backtrace}")

          error = true

        end

        if message_args.abort || error
          EventQ::NonceManager.failed(message.id)
          reject_message(queue, client, msg, q, retry_attempts, message, message_args.abort)
        else
          EventQ::NonceManager.complete(message.id)
        end

        return true
      end

      def reject_message(queue, client, msg, q, retry_attempts, message, abort)

        if !queue.allow_retry || retry_attempts >= queue.max_retry_attempts

          EventQ.log(:info, "[#{self.class}] - Message rejected removing from queue. Message: #{serialize_message(message)}")

          #remove the message from the queue so that it does not get retried again
          client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

          if retry_attempts >= queue.max_retry_attempts

            EventQ.log(:info, "[#{self.class}] - Message retry attempt limit exceeded.")

            if @retry_exceeded_block != nil
              EventQ.log(:info, "[#{self.class}] - Executing retry exceeded block.")
              begin
                @retry_exceeded_block.call(message)
              rescue => e
                EventQ.log(:error, "[#{self.class}] - An error occurred executing the on retry block. Error: #{e}")
              end
            end

          end

        elsif queue.allow_retry

          retry_attempts += 1

          EventQ.log(:info, "[#{self.class}] - Message rejected requesting retry. Attempts: #{retry_attempts}")

          if queue.allow_retry_back_off == true
            EventQ.log(:debug, "[#{self.class}] - Calculating message back off retry delay. Attempts: #{retry_attempts} * Delay: #{queue.retry_delay}")
            visibility_timeout = (queue.retry_delay * retry_attempts) / 1000
            if visibility_timeout > (queue.max_retry_delay / 1000)
              EventQ.log(:debug, "[#{self.class}] - Max message back off retry delay reached.")
              visibility_timeout = queue.max_retry_delay / 1000
            end
          else
            EventQ.log(:debug, "[#{self.class}] - Setting fixed retry delay for message.")
            visibility_timeout = queue.retry_delay / 1000
          end

          if visibility_timeout > 43200
            EventQ.log(:debug, "[#{self.class}] - AWS max visibility timeout of 12 hours has been exceeded. Setting message retry delay to 12 hours.")
            visibility_timeout = 43200
          end

          EventQ.log(:debug, "[#{self.class}] - Sending message for retry. Message TTL: #{visibility_timeout}")
          client.sqs.change_message_visibility({
                                               queue_url: q, # required
                                               receipt_handle: msg.receipt_handle, # required
                                               visibility_timeout: visibility_timeout.to_s, # required
                                           })

          if @on_retry_block
            EventQ.log(:debug, "[#{self.class}] - Executing on retry block.")
            begin
              @on_retry_block.call(message, abort)
            rescue => e
              EventQ.log(:error, "[#{self.class}] - An error occurred executing the on retry block. Error: #{e}")
            end
          end

        end

      end

      def configure(queue, options = {})

        @queue = queue

        #default thread count
        @thread_count = 5
        if options.key?(:thread_count)
          @thread_count = options[:thread_count]
        end

        #default sleep time in seconds
        @sleep = 5
        if options.key?(:sleep)
          @sleep = options[:sleep]
        end

        @fork_count = 1
        if options.key?(:fork_count)
          @fork_count = options[:fork_count]
        end

        if options.key?(:gc_flush_interval)
          @gc_flush_interval = options[:gc_flush_interval]
        end

        if options.key?(:queue_poll_wait)
          @queue_poll_wait = options[:queue_poll_wait]
        end

        EventQ.log(:info, "[#{self.class}] - Configuring. Process Count: #{@fork_count} | Thread Count: #{@thread_count} | Interval Sleep: #{@sleep} | GC Flush Interval: #{@gc_flush_interval} | Queue Poll Wait: #{@queue_poll_wait}.")

        return true

      end

    end
  end
end
