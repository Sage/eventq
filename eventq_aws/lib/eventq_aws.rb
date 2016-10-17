require 'aws-sdk-core'
require 'eventq_base'

require 'eventq_aws/version'
require 'eventq_aws/aws_eventq_client'
require 'eventq_aws/aws_queue_client'
require 'eventq_aws/aws_queue_manager'
require 'eventq_aws/aws_queue_worker'
require 'eventq_aws/aws_subscription_manager'

module EventQ
  def self.namespace
    @namespace
  end
  def self.namespace=(value)
    @namespace = value
  end
  def self.create_event_type(event_type)
    if EventQ.namespace == nil
      return event_type
    end
    return "#{EventQ.namespace}-#{event_type}"
  end
end

