# frozen_string_literal: true

module EventQ
  module Amazon
    # Raise SNS events in a format readily understood / expected by Domain
    # services.
    class DomainEventQClient < EventQClient
      def raise_event(event_type, event, context = {}, region = nil)
        register_event(event_type, region)

        with_domain_message(event_type, event, context) do |message|
          topic_arn = topic_arn(event_type, region)
          response = @client.sns(region).publish(
            topic_arn: topic_arn,
            message: message,
            subject: event_type
          )

          EventQ.logger.debug do
            "[#{self.class} #raise_event] - Published to SNS with topic_arn: #{topic_arn} | event_type: #{event_type} | Message: #{message}"
          end

          response
        end
      end

      private

      def with_domain_message(event_type, event, correlation)
        msg = DomainMessage.new
        msg.topic = event_type
        msg.content = event
        msg.correlation = correlation

        # TODO: check if we need a signature property
        message = serialized_message(msg)

        response = yield(message)

        EventQ.log(:debug, "[#{self.class}] - Raised event. Message: #{message} | Type: #{event_type}.")

        response.message_id
      end
    end
  end
end
