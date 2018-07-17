module EventQ
  module RabbitMq
    class QueueWorkerV2 < EventQ::RabbitMq::QueueWorker
      # This method should not be called iteratively and will sit in a loop
      # The reason is because this uses a push notification from the subscribe mechanism to trigger the
      # block and will exit if you do not block.
      def thread_process_iteration(queue, options, block)
        @is_running = true
        manager = options[:manager]
        channel = options[:connection].create_channel
        # channel.prefetch(1)

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

        # we don't want to stop the subscribe process
        while running?
          sleep 5
        end

        if channel != nil && channel.open?
          channel.close
        end
      end
    end
  end
end

