require 'eventq_base'
require 'bunny'
require 'oj'
require 'hash_kit'
require_relative '../lib/eventq_rabbitmq/version'
require_relative '../lib/eventq_rabbitmq/rabbitmq_queue_client'
require_relative '../lib/eventq_rabbitmq/rabbitmq_queue_manager'
require_relative '../lib/eventq_rabbitmq/rabbitmq_queue_worker'
require_relative '../lib/eventq_rabbitmq/rabbitmq_subscription_manager'
require_relative '../lib/eventq_rabbitmq/rabbitmq_eventq_client'
require_relative '../lib/eventq_rabbitmq/default_queue'
require_relative '../lib/eventq_rabbitmq/rabbitmq_status_checker'

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
  def self.create_exchange_name(exchange_name)
    if EventQ.namespace == nil
      return exchange_name
    end
    return "#{EventQ.namespace}-#{exchange_name}"
  end
end