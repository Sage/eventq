module EventQ
  module Amazon
    class QueueClient

      def initialize(options = {})
        if options.has_key?(:aws_key)
          Aws.config[:credentials] = Aws::Credentials.new(options[:aws_key], options[:aws_secret])
        end

        if !options.has_key?(:aws_account_number)
          raise ':aws_account_number option must be specified.'.freeze
        end

        @aws_account = options[:aws_account_number]

        @sns_keep_alive_timeout = options[:sns_keep_alive_timeout] || 30
        @sns_continue_timeout = options[:sns_continue_timeout] || 15

        if options.has_key?(:aws_region)
          @aws_region = options[:aws_region]
          Aws.config[:region] = @aws_region
        else
          @aws_region = Aws.config[:region]
        end
      end

      # Returns the AWS SQS Client
      def sqs
        @sqs ||= Aws::SQS::Client.new
      end

      # Returns the AWS SNS Client
      def sns
        @sns ||= Aws::SNS::Client.new(
          http_idle_timeout: @sns_keep_alive_timeout,
          http_continue_timeout: @sns_continue_timeout
        )
      end

      def get_topic_arn(event_type)
        _event_type = EventQ.create_event_type(event_type)
        return "arn:aws:sns:#{@aws_region}:#{@aws_account}:#{aws_safe_name(_event_type)}"
      end

      def get_queue_arn(queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        return "arn:aws:sqs:#{@aws_region}:#{@aws_account}:#{aws_safe_name(_queue_name)}"
      end

      def create_topic_arn(event_type)
        _event_type = EventQ.create_event_type(event_type)
        response = sns.create_topic(name: aws_safe_name(_event_type))
        return response.topic_arn
      end

      # Returns the URL of the queue. The queue will be created when it does
      #
      # @param queue [EventQ::Queue]
      def get_queue_url(queue)
        _queue_name = EventQ.create_queue_name(queue.name)
        response= sqs.get_queue_url(
                                     queue_name: aws_safe_name(_queue_name),
                                     queue_owner_aws_account_id: @aws_account,
                                   )
        return response.queue_url
      end

      def aws_safe_name(name)
        return name[0..79].gsub(/[^a-zA-Z\d_\-]/,'')
      end

      def keep_alive(connections: 5, interval: 1)
        connections.times do
          Thread.new do
            while true do
              begin
                Seahorse::Client::NetHttp::ConnectionPool.pools.each do |cp|
                  pool = cp.instance_variable_get(:@pool)
                  pool.each do |k,v|
                    cp.session_for(URI(k)) do |session|
                      session.request(Net::HTTP::Get.new('/'))
                    end
                  end
                end
              rescue
                # swallow error and do nothing
              end
              sleep interval
            end
          end
        end
      end
    end
  end
end
