class RabbitMqQueueWorker

  attr_accessor :is_running

  def initialize
    @threads = []
    @is_running = false

    @retry_exceeded_block = nil
  end

  def start(queue, options = {}, &block)

    configure(queue, options)

    puts '[QUEUE_WORKER] Listening for messages.'

    raise 'Worker is already running.' if running?

    @is_running = true
    @threads = []

    #loop through each thread count
    @thread_count.times do
      thr = Thread.new do

        client = RabbitMqQueueClient.new
        manager = RabbitMqQueueManager.new

        #begin the queue loop for this thread
        while true do

          #check if the worker is still allowed to run and break out of thread loop if not
          if !@is_running
            break
          end

          channel = client.get_channel

          #get the queue
          q = manager.get_queue(channel, queue)
          retry_exchange = manager.get_retry_exchange(channel, queue)

          received = false
          error = false

          begin
            delivery_info, properties, payload = q.pop(:manual_ack => true, :block => true)

            #check that message was received
            if payload != nil

              message = Oj.load(payload)

              puts "[QUEUE_WORKER] Message received. Retry Attempts: #{message.retry_attempts}"
              puts properties

              #begin worker block for queue message
              begin
                block.call(message.content, message.type, message.retry_attempts)

                #accept the message as processed
                channel.acknowledge(delivery_info.delivery_tag, false)
                puts '[QUEUE_WORKER] Message acknowledged.'
                received = true
              rescue => e
                puts '[QUEUE_WORKER] An unhandled error happened attempting to process a queue message.'
                puts "Error: #{e}"

                #reject the message to remove from queue
                channel.reject(delivery_info.delivery_tag, false)
                error = true
                puts '[QUEUE_WORKER] Message rejected.'

                #check if the message is allowed to be retried
                if queue.allow_retry

                  puts '[QUEUE_WORKER] Checking retry attempts...'
                  if message.retry_attempts < queue.max_retry_attempts
                    puts'[QUEUE_WORKER] Incrementing retry attempts count.'
                    message.retry_attempts += 1
                    puts '[QUEUE_WORKER] Sending message for retry.'
                    retry_exchange.publish(Oj.dump(message))
                    puts '[QUEUE_WORKER] Published message to retry exchange.'
                  else
                    if @retry_exceeded_block != nil
                      @retry_exceeded_block.call(message)
                    else
                      raise "[QUEUE_WORKER] No retry exceeded block specified."
                    end
                  end
                end

              end

            end

          rescue Timeout::Error
            puts 'Timeout occured attempting to pop a message from the queue.'
          end

          #check if any message was received
          if !received && !error
            puts "[QUEUE_WORKER] No message received. Sleeping for #{@sleep} seconds"
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

  end

  def stop
    @is_running = false
    @threads.each { |thr| thr.join }
  end

  def on_retry_exceeded(&block)
    @retry_exceeded_block = block
  end

  def running?
    @is_running
  end

  private

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

  end

end
