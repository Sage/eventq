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
      def create_topic_arn(event_type, region = nil)
        _event_type = EventQ.create_event_type(event_type)
        topic_key = "#{region}:#{_event_type}"

        arn = get_topic_arn(event_type, region)
        unless arn
          response = sns.create_topic(name: aws_safe_name(_event_type))
          arn = response.topic_arn
          @@topic_arns[topic_key] = arn
        end

        arn
      end

      # Check if a TopicArn exists.  This will check with AWS if necessary and cache the results if one is found
      #
      # @return TopicArn [String]
      def get_topic_arn(event_type, region = nil)
        _event_type = EventQ.create_event_type(event_type)
        topic_key = "#{region}:#{_event_type}"

        arn = @@topic_arns[topic_key]
        unless arn
          arn = find_topic(_event_type)

          @@topic_arns[topic_key] = arn if arn
        end

        arn
      end

      def drop_topic(event_type, region = nil)
        topic_arn = get_topic_arn(event_type, region)
        sns.delete_topic(topic_arn: topic_arn)

        _event_type = EventQ.create_event_type(event_type)
        topic_key = "#{region}:#{_event_type}"
        @@topic_arns.delete(topic_key)

        true
      end

      def aws_safe_name(name)
        return name[0..79].gsub(/[^a-zA-Z\d_\-]/,'')
      end

      private

      # Finds the given topic, or returns nil if the topic could not be found
      #
      # @note Responses to list_topics can be paged, so to check *all* topics
      # we'll need to request each page of topics using response.next_token for
      # until the response no longer contains a next_token. Requests to
      # list_topics are throttled to 30 TPS, so in the future we may need to
      # handle this if it becomes a problem.
      #
      # @param topic_name [String] the name of the topic to find
      # @return [String]
      def find_topic(topic_name)
        response = sns.list_topics
        topics = response.topics
        arn = topics.detect { |topic| topic.topic_arn.end_with?(":#{topic_name}") }&.topic_arn

        while arn.nil? && response.next_token
          response = sns.list_topics(next_token: response.next_token)
          topics = response.topics
          arn = topics.detect { |topic| topic.topic_arn.end_with?(":#{topic_name}") }&.topic_arn
        end

        arn
      end
    end
  end
end
