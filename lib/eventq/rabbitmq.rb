require 'bunny'

require 'hash_kit'
require_relative './eventq_rabbitmq/rabbitmq_queue_client'
require_relative './eventq_rabbitmq/rabbitmq_queue_manager'
require_relative './eventq_rabbitmq/rabbitmq_queue_worker'
require_relative './eventq_rabbitmq/rabbitmq_subscription_manager'
require_relative './eventq_rabbitmq/rabbitmq_eventq_client'
require_relative './eventq_rabbitmq/default_queue'
require_relative './eventq_rabbitmq/rabbitmq_status_checker'

module EventQ
  def self.create_exchange_name(exchange)
    create_queue_name(exchange)
  end
end
