# frozen_string_literal: true

require 'concurrent'

module EventQ
  module Amazon
    # Helper SNS class to handle the API calls
    class SNS
      @@topic_arns = Concurrent::Hash.new

      attr_reader :sns

      def initialize(client)
        @sns = client
      end

      # Create a TopicArn. if one already exists, it will return a pre-existing ARN from the cache.
      # Even in the event of multiple threads trying to create one with AWS, AWS is idempotent and won't create
      # duplicates
      def create_topic_arn(event_type)
        _event_type = EventQ.create_event_type(event_type)

        arn = get_topic_arn(event_type)
        unless arn
          response = sns.create_topic(name: aws_safe_name(_event_type))
          arn = response.topic_arn
          @@topic_arns[_event_type] = arn
        end

        arn
      end

      # Check if a TopicArn exists.  This will check with AWS if necessary and cache the results if one is found
      # @return TopicArn [String]
      def get_topic_arn(event_type)
        _event_type = EventQ.create_event_type(event_type)

        arn = @@topic_arns[event_type]
        unless arn
          response = sns.list_topics
          arn = response.topics.detect { |topic| topic.topic_arn.end_with?(_event_type) }&.topic_arn

          @@topic_arns[_event_type] = arn if arn
        end

        arn
      end

      def drop_topic(event_type)
        topic_arn = get_topic_arn(event_type)
        sns.delete_topic(topic_arn: topic_arn)

        _event_type = EventQ.create_event_type(event_type)
        @@topic_arns.delete(_event_type)

        true
      end

      def aws_safe_name(name)
        return name[0..79].gsub(/[^a-zA-Z\d_\-]/,'')
      end
    end
  end
end
