module EventQ
  module Amazon
    class QueueWorker

      attr_accessor :is_running

      def initialize
        @threads = []
        @forks = []
        @is_running = false

        @retry_exceeded_block = nil

        @hash_helper = HashKit::Helper.new
        @serialization_provider_manager = EventQ::SerializationProviders::Manager.new
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

              thread_process_iteration(client, manager, queue, block)

            end

          end
          @threads.push(thr)

        end

        if options.key?(:wait) && options[:wait] == true
          @threads.each { |thr| thr.join }
        end

      end

      def thread_process_iteration(client, manager, queue, block)
        #get the queue
        q = manager.get_queue(queue)

        received = false
        error = false
        abort = false

        begin

          #request a message from the queue
          response = client.sqs.receive_message({
                                                    queue_url: q,
                                                    max_number_of_messages: 1,
                                                    wait_time_seconds: 1,
                                                    attribute_names: ['ApproximateReceiveCount']
                                                })

          #check that a message was received
          if response.messages.length > 0

            msg = response.messages[0]
            retry_attempts = msg.attributes['ApproximateReceiveCount'].to_i - 1

            #deserialize the message payload
            payload = JSON.load(msg.body)
            message = deserialize_message(payload["Message"])

            message_args = EventQ::MessageArgs.new(message.type, retry_attempts)

            EventQ.log(:debug, "[#{self.class}] - Message received. Retry Attempts: #{retry_attempts}")

            #begin worker block for queue message
            begin

              block.call(message.content, message_args)

              if message_args.abort == true
                abort = true
                EventQ.log(:info, "[#{self.class}] - Message aborted.")
              else
                #accept the message as processed
                client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })
                EventQ.log(:info, "[#{self.class}] - Message acknowledged.")
                received = true
              end

            rescue => e
              EventQ.log(:error, "[#{self.class}] - An unhandled error happened while attempting to process a queue message. Error: #{e.backtrace}")

              error = true

            end

            if abort || error
              EventQ.log(:info, "[#{self.class}] - Message rejected.")
              reject_message(queue, client, msg, q, retry_attempts)
            end

          end

        rescue => e
          EventQ.log(:error, "[#{self.class}] - An error occurred attempting to retrieve a message from the queue. Error: #{e.backtrace}")
        end

        GC.start

        #check if any message was received
        if !received && !error
          EventQ.log(:debug, "[#{self.class}] - No message received. Sleeping for #{@sleep} seconds")
          #no message received so sleep before attempting to pop another message from the queue
          sleep(@sleep)
        end
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

      def running?
        return @is_running
      end

      def deserialize_message(payload)
        provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
        return provider.deserialize(payload)
      end

      private

      def reject_message(queue, client, msg, q, retry_attempts)

        if !queue.allow_retry || retry_attempts >= queue.max_retry_attempts
          #remove the message from the queue so that it does not get retried again
          client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })

          if retry_attempts >= queue.max_retry_attempts

            EventQ.log(:info, "[#{self.class}] - Message retry attempt limit exceeded.")

            if @retry_exceeded_block != nil
              EventQ.log(:debug, "[#{self.class}] - Executing retry exceeded block.")
              @retry_exceeded_block.call(message)
            end

          end

        elsif queue.allow_retry

          retry_attempts += 1

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
        @sleep = 15
        if options.key?(:sleep)
          @sleep = options[:sleep]
        end

        @fork_count = 1
        if options.key?(:fork_count)
          @fork_count = options[:fork_count]
        end

        EventQ.log(:info, "[#{self.class}] - Configuring. Process Count: #{@fork_count} | Thread Count: #{@thread_count} | Interval Sleep: #{@sleep}.")

        return true

      end

    end
  end
end
