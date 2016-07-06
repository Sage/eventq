module EventQ
  module Amazon
    class QueueWorker

      attr_accessor :is_running

      def initialize
        @threads = []
        @is_running = false

        @retry_exceeded_block = nil
      end

      def start(queue, options = {}, &block)

        EventQ.logger.debug '[EVENTQ_AWS::QUEUE_WORKER] - Preparing to start listening for messages.'

        configure(queue, options)

        if options[:client] == nil
          raise ':client (QueueClient) must be specified.'
        end

        raise 'Worker is already running.' if running?

        EventQ.logger.debug '[EVENTQ_AWS::QUEUE_WORKER] - Listening for messages.'

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
                                                          message_attribute_names: ['ApproximateReceiveCount']
                                                      })

                #check that a message was received
                if response.messages.length > 0

                  msg = response.messages[0]
                  retry_attempts = msg.message_attributes['ApproximateReceiveCount'].to_i

                  #deserialize the message payload
                  message = Oj.load(msg.body)
                  payload = Oj.load(message["Message"])

                  message_args = EventQ::MessageArgs.new(payload.type, retry_attempts)

                  EventQ.logger.debug "[EVENTQ_AWS::QUEUE_WORKER] - Message received. Retry Attempts: #{retry_attempts}"

                  #begin worker block for queue message
                  begin

                    block.call(payload.content, message_args)

                    if message_args.abort == true
                      abort = true
                      EventQ.logger.debug '[EVENTQ_AWS::QUEUE_WORKER] - Message aborted.'
                    else
                      #accept the message as processed
                      client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })
                      EventQ.logger.debug '[EVENTQ_AWS::QUEUE_WORKER] - Message acknowledged.'
                      received = true
                    end

                  rescue => e
                    EventQ.logger.debug "[EVENTQ_AWS::QUEUE_WORKER] - An unhandled error happened while attempting to process a queue message. Error: #{e}"

                    error = true

                  end

                  if abort || error
                    EventQ.logger.debug '[EVENTQ_AWS::QUEUE_WORKER] - Message rejected.'
                    reject_message(queue, client, msg, q, retry_attempts)
                  end

                end

              rescue => e
                EventQ.logger.error "[EVENTQ_AWS::QUEUE_WORKER] - An error occured attempting to retrieve a message from the queue. Error: #{e}"
              end

              #check if any message was received
              if !received && !error
                EventQ.logger.error "[EVENTQ_AWS::QUEUE_WORKER] - No message received. Sleeping for #{@sleep} seconds"
                #no message received so sleep before attempting to pop another message from the queue
                sleep(@sleep)
              end

            end

          end
          @threads.push(thr)

        end

        if options.key?(:wait) && options[:wait] == true
          @threads.each { |thr| thr.join }
        end

        return true
      end

      def stop
        EventQ.logger.debug '[EVENTQ_AWS::QUEUE_WORKER] - Stopping.'
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

      private

      def reject_message(queue, client, msg, q, retry_attempts)
        if !queue.allow_retry || retry_attempts >= queue.max_retry_attempts

          #remove the message from the queue so that it does not get retried again
          client.sqs.delete_message({ queue_url: q, receipt_handle: msg.receipt_handle })
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

        EventQ.logger.debug "[EVENTQ_AWS::QUEUE_WORKER] - Configuring. Thread Count: #{@thread_count} | Interval Sleep: #{@sleep}."

        return true

      end

    end
  end
end
