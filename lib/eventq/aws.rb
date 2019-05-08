require 'aws-sdk-core'
require 'eventq'

require_relative './eventq_aws/aws_calculate_visibility_timeout'
require_relative './eventq_aws/aws_eventq_client'
require_relative './eventq_aws/sns'
require_relative './eventq_aws/sqs'
require_relative './eventq_aws/aws_queue_client'
require_relative './eventq_aws/aws_queue_manager'
require_relative './eventq_aws/aws_subscription_manager'
require_relative './eventq_aws/aws_status_checker'
require_relative './eventq_aws/aws_queue_worker'

module EventQ
end

