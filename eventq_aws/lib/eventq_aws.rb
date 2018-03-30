require 'aws-sdk-core'
require 'eventq_base'

require 'eventq_aws/version'
require 'eventq_aws/aws_eventq_client'
require 'eventq_aws/aws_queue_client'
require 'eventq_aws/aws_queue_manager'
require 'eventq_aws/aws_subscription_manager'
require_relative 'eventq_aws/aws_status_checker'

if RUBY_PLATFORM =~ /java/
  require 'eventq_aws/jruby/aws_queue_worker'
else
  require 'eventq_aws/aws_queue_worker'
end

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
  def self.create_queue_name(queue_name)
    if EventQ.namespace == nil
      return queue_name
    end
    return "#{EventQ.namespace}-#{queue_name}"
  end
end

