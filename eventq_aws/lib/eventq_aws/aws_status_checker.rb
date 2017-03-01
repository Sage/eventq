module EventQ
  module Amazon
    class StatusChecker

      def initialize(queue_manager:, client:)

        if queue_manager == nil
          raise 'queue_manager  must be specified.'.freeze
        end

        @queue_manager = queue_manager

      end

      def queue?(queue)
        @queue_manager.queue_exists?(queue)
      end

      def event_type?(event_type)
        @queue_manager.topic_exists?(event_type)
      end

    end
  end
end