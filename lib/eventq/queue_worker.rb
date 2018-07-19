# frozen_string_literal: true

require 'eventq/worker_status'

module EventQ
  class QueueWorker
    attr_accessor :is_running
    attr_reader :worker_status, :worker_adapter, :reader, :writer

    def initialize
      @worker_status = EventQ::WorkerStatus.new
      @is_running = false
      @last_gc_flush = Time.now
      @gc_flush_interval = 10
    end

    def start(queue, options = {}, &block)
      EventQ.logger.info("[#{self.class}] - Preparing to start listening for messages.")

      # Make sure mandatory options are specified
      mandatory = [:worker_adapter, :client]
      missing = mandatory - options.keys
      raise "[#{self.class}] - Missing options. #{missing} must be specified." unless missing.empty?

      @worker_adapter = options[:worker_adapter]
      worker_adapter.context = self

      raise "[#{self.class}] - Worker is already running." if running?

      configure(queue, options)
      worker_adapter.configure(options)

      queue_name = EventQ.create_queue_name(queue.name)
      EventQ.logger.info("[#{self.class}] - Listening for messages on queue: #{queue_name}}")

      # Initialize the pipes for inter-process communication when using forks
      @reader, @writer = IO.pipe

      # Allow the worker to be started on a thread or on the main process.
      # Using the thread won't block the parent process, whereas starting on the main process will.
      if @block_process
        start_worker(block, options, queue)
      else
        Thread.new { start_worker(block, options, queue) }
      end
      @is_running = true
    end

    def start_worker(block, options, queue)
      if @fork_count > 0
        @fork_count.times do
          fork do
            start_process(options, queue, block)
          end
        end
        build_worker_status
        Process.waitall
      else
        start_process(options, queue, block)
      end
    end

    def start_process(options, queue, block)
      %w'INT TERM'.each do |sig|
        Signal.trap(sig) {
          stop
          exit
        }
      end

      # need to set it again since we might be in a fork.
      @is_running = true
      tracker = track_process(Process.pid)

      # Execute any specific adapter worker logic before the threads are launched.
      # This could range from setting instance variables, extra options, etc.
      worker_adapter.pre_process(self, options)

      if @thread_count > 0
        @thread_count.times do
          thr = Thread.new do
            start_thread(queue, options, block)
          end

          # Allow the thread to kill the parent process if an error occurs
          thr.abort_on_exception = true
          track_thread(tracker, thr)
        end
      else
        start_thread(queue, options, block)
      end

      marshal_worker_status(tracker) if @fork_count > 0

      # Only on the main process should you be able to not wait on a thread, otherwise
      # any forked process will just immediately quit
      unless options[:wait] == false && options[:fork_count] == 0
        worker_status.threads.each { |thr| thr.thread.join }
      end
    end

    def start_thread(queue, options, block)
      worker_adapter.thread_process_iteration(queue, options, block)
    rescue Exception => e # rubocop:disable Lint/RescueException
      EventQ.logger.error(e)
      call_on_error_block(error: e, message: e.message)
      raise Exceptions::WorkerThreadError, e.message, e.backtrace
    end

    def stop
      EventQ.logger.info("[#{self.class}] - Stopping.")
      @is_running = false
      # Need to notify all processes(forks) to stop as well.
      worker_status.processes.each { |process| Process.kill('TERM', process.pid) if Process.pid != process.pid }
    end

    def running?
      @is_running
    end

    def deserialize_message(payload)
      provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
      provider.deserialize(payload)
    end

    def serialize_message(msg)
      provider = @serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
      provider.serialize(msg)
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

    def configure(queue, options = {})
      # default thread count
      @thread_count = 1
      if options.key?(:thread_count)
        @thread_count = options[:thread_count] if options[:thread_count] > 0
      end

      # default sleep time in seconds
      @sleep = 0
      if options.key?(:sleep)
        EventQ.logger.warn("[#{self.class}] - :sleep is deprecated.")
      end

      @fork_count = 0
      if options.key?(:fork_count)
        @fork_count = options[:fork_count]
      end

      if options.key?(:gc_flush_interval)
        @gc_flush_interval = options[:gc_flush_interval]
      end

      # The default is to block the process where the worker starts.
      # You may not want it to block if an application needs to run multiple things at the same time.
      # Example:  Running a background worker and a web service on the same application.
      @block_process = true
      if options.key?(:block_process)
        @block_process = options[:block_process]
      end

      message_list = [
          "Process Count: #{@fork_count}",
          "Thread Count: #{@thread_count}",
          "Interval Sleep: #{@sleep}",
          "GC Flush Interval: #{@gc_flush_interval}",
          "Block process: #{@block_process}"
      ]
      EventQ.logger.info("[#{self.class}] - Configuring. #{message_list.join(' | ')}")
    end

    def on_retry_exceeded(&block)
      @on_retry_exceeded_block = block
    end

    def on_retry(&block)
      @on_retry_block = block
    end

    def on_error(&block)
      @on_error_block = block
    end

    def call_on_error_block(error:, message: nil)
      call_block(:on_error_block, error, message)
    end

    def call_on_retry_exceeded_block(message)
      call_block(:on_retry_exceeded_block, message)
    end

    def call_on_retry_block(message)
      call_block(:on_retry_block, message)
    end

    private

    # This method is only used when forks need to communicate info about the fork to the main process.
    def build_worker_status
      writer.close
      while raw_data = reader.gets
        data = Marshal.load(raw_data)
        worker_status.processes.push data
      end
      reader.close
    end

    # Sends the tracker info via IO::Pipe.  This is needed when using forks and need to communicate information
    # between processes.
    def marshal_worker_status(tracker)
      x = tracker.class.new(tracker.pid)
      tracker.threads.each { |thr| x.threads.push thr.to_s }
      reader.close
      # There "seems" to be a concurrency issue around using Pipes. On occasion, not getting newline character
      # when expected, so will have each fork wait a bit when starting up.
      # Sleep for a random decimal between 0 and 1.
      sleep rand
      writer.puts Marshal.dump(x)
    end

    def call_block(block_name, *args)
      block_variable = "@#{block_name}"
      if instance_variable_get(block_variable)
        EventQ.logger.debug { "[#{self.class}] - Executing #{block_variable}." }
        begin
          instance_variable_get(block_variable).call(*args)
        rescue => e
          EventQ.logger.error("[#{self.class}] - An error occurred executing the #{block_variable}. Error: #{e}")
        end
      else
        EventQ.logger.debug { "[#{self.class}] - No #{block_variable} specified." }
      end
    end

    def track_process(pid)
      tracker = EventQ::WorkerProcess.new(pid)
      worker_status.processes.push(tracker)
      tracker
    end

    def track_thread(process_tracker, thread)
      tracker = EventQ::WorkerThread.new(thread)
      process_tracker.threads.push(tracker)
      tracker
    end
  end
end
