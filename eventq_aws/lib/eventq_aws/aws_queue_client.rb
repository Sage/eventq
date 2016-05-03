class AwsQueueClient

  attr_reader :sns
  attr_reader :sqs

  def initialize

    Aws.config[:credentials] = Aws::Credentials.new(ENV['AWS_KEY'], ENV['AWS_SECRET'])
    Aws.config[:region] = ENV['AWS_REGION'] || 'us-west-2'

    @sns = Aws::SNS::Client.new
    @sqs = Aws::SQS::Client.new

    @aws_account = ENV['AWS_ACCOUNT_NUMBER']
    @aws_region = ENV['AWS_REGION'] || 'us-west-2'

  end

  def get_topic_arn(event_type)
    response = @sns.create_topic({ name: event_type })
    return response.topic_arn
  end

  def get_queue_arn(queue)
    return "arn:aws:sqs:#{@aws_region}:#{@aws_account}:#{queue.name}"
  end

end