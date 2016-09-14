module EventQ
  module RabbitMq
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

        raise "[#{self.class}] - Worker is already running." if running?

        if options[:client] == nil
          raise "[#{self.class}] - :client (QueueClient) must be specified."
        end

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

        connection = client.get_connection

        @threads = []

        #loop through each thread count
        @thread_count.times do
          thr = Thread.new do

            #begin the queue loop for this thread
            while true do

              #check if the worker is still allowed to run and break out of thread loop if not
              if !@is_running
                break
              end

              begin

                channel = connection.create_channel

                thread_process_iteration(channel, manager, queue, block)

              rescue => e
                EventQ.logger.error "An unhandled error occurred attempting to communicate with RabbitMQ. Error: #{e} | Backtrace: #{e.backtrace}"
              end

              if channel != nil && channel.status != :closed
                channel.close
              end

            end

          end
          @threads.push(thr)

        end

        if options.key?(:wait) && options[:wait] == true
          @threads.each { |thr| thr.join }
          connection.close
        end

        return true

      end

      def thread_process_iteration(channel, manager, queue, block)

        #get the queue
        q = manager.get_queue(channel, queue)
        retry_exchange = manager.get_retry_exchange(channel, queue)

        received = false
        error = false
        abort = false

        begin
          delivery_info, properties, payload = q.pop(:manual_ack => true, :block => true)

          #check that message was received
          if payload != nil

            message = deserialize_message(payload)

            EventQ.log(:debug, "[#{self.class}] - Message received. Retry Attempts: #{message.retry_attempts}")

            message_args = EventQ::MessageArgs.new(message.type, message.retry_attempts)

            #begin worker block for queue message
            begin
              block.call(message.content, message_args)

              if message_args.abort == true
                abort = true
                EventQ.log(:info, "[#{self.class}] - Message aborted.")
              else
                #accept the message as processed
                channel.acknowledge(delivery_info.delivery_tag, false)
                EventQ.log(:info, "[#{self.class}] - Message acknowledged.")
                received = true
              end

            rescue => e
              EventQ.log(:error, "[#{self.class}] - An unhandled error happened attempting to process a queue message. Error: #{e} | Backtrace: #{e.backtrace}")
              error = true
            end

            if error || abort
              reject_message(channel, message, delivery_info, retry_exchange, queue)
            end

          end

        rescue => e
          EventQ.log(:error, "[#{self.class}] - An error occurred attempting to pop a message from the queue. Error: #{e} | Backtrace: #{e.backtrace}")
        end

        channel.close

        GC.start

        #check if any message was received
        if !received && !error
          EventQ.log(:debug, "[#{self.class}] - No message received. Sleeping for #{@sleep} seconds")
          #no message received so sleep before attempting to pop another message from the queue
          sleep(@sleep)
        end
      end

      def stop
        puts "[#{self.class}] - Stopping..."
        @is_running = false
        @threads.each { |thr| thr.join }

        return true
      end

      def on_retry_exceeded(&block)
        @retry_exceeded_block = block
        return nil
      end

      def running?
        return @is_running
      end

      def deserialize_message(payload)
        provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
        return provider.deserialize(payload)
      end

      def reject_message(channel, message, delivery_info, retry_exchange, queue)
        #reject the message to remove from queue
        channel.reject(delivery_info.delivery_tag, false)

        EventQ.log(:info, "[#{self.class}] - Message rejected.")

        #check if the message is allowed to be retried
        if queue.allow_retry

          EventQ.log(:debug, "[#{self.class}] - Checking retry attempts...")

          if message.retry_attempts < queue.max_retry_attempts
            EventQ.log(:debug, "[#{self.class}] - Incrementing retry attempts count.")
            message.retry_attempts += 1

            if queue.allow_retry_back_off == true
              EventQ.log(:debug, "[#{self.class}] - Calculating message back off retry delay. Attempts: #{message.retry_attempts} * Retry Delay: #{queue.retry_delay}")
              message_ttl = message.retry_attempts * queue.retry_delay
              if (message.retry_attempts * queue.retry_delay) > queue.max_retry_delay
                EventQ.log(:debug, "[#{self.class}] - Max message back off retry delay reached.")
                message_ttl = queue.max_retry_delay
              end
            else
              EventQ.log(:debug, "[#{self.class}] - Setting fixed retry delay for message.")
              message_ttl = queue.retry_delay
            end

            EventQ.log(:debug, "[#{self.class}] - Sending message for retry. Message TTL: #{message_ttl}")
            retry_exchange.publish(Oj.dump(message), :expiration => message_ttl)
            EventQ.log(:debug, "[#{self.class}] - Published message to retry exchange.")

          else

            EventQ.log(:info, "[#{self.class}] - Message retry attempts exceeded.")

            if @retry_exceeded_block != nil
              EventQ.log(:debug, "[#{self.class}] - Executing retry exceeded block.")
              @retry_exceeded_block.call(message)
            else
              EventQ.log(:debug, "[#{self.class}] - No retry exceeded block specified.")
            end

          end

        end

        return true

      end

      def configure(queue, options = {})

        @queue = queue

        #default thread count
        @thread_count = 4
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

