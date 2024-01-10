RSpec.shared_context 'aws_wait_for_message_processed_helper' do
  let(:aws_message_processed_queue) { Queue.new }

  # Ensure spec breaks after 10 seconds to prevent waiting for next result forever
  around do |example|
    Timeout::timeout(10) { example.run }
  end

  # The method `untag_processing_thread` is called after each time a message is processed
  before do
    allow(subject).to receive(:untag_processing_thread).and_wrap_original do |original_method, *args, &block|
      aws_message_processed_queue.push(true)
      original_method.call(*args, &block)
    end
  end

  # Waits for result on the queue and time out after 10 seconds due to the around block
  def wait_for_message_processed
    aws_message_processed_queue.pop
  end
end

RSpec.shared_context 'mock_aws_visibility_timeout' do
  let(:aws_visibility_timeout_queue) { Queue.new }

  # Ensure spec breaks after 5 seconds to prevent waiting for next result forever
  around do |example|
    Timeout::timeout(5) { example.run }
  end

  before do
    # Store visibility timeout for checking expectations, but return timeout of zero to speed up specs
    allow(subject).to receive(:calculate_visibility_timeout).and_wrap_original do |original_method, *args, &block|
      result = original_method.call(*args, &block)
      aws_visibility_timeout_queue.push(call: args.first, visibility_timeout: result)
      0
    end
  end
end
