RSpec.describe EventQ::RabbitMq::QueueWorker do

  let(:client) do
    return EventQ::RabbitMq::QueueClient.new({ endpoint: 'rabbitmq' })
  end

  let(:connection) { client.get_connection }

  let(:channel) { connection.create_channel }

  after do
    channel.close
    connection.close
  end

  describe '#deserialize_message' do
    context 'when serialization provider is OJ_PROVIDER' do
      before do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
      context 'when payload is for a known type' do
        let(:a) do
          A.new.tap do |a|
            a.text = 'ABC'
          end
        end
        let(:payload) { Oj.dump(a) }
        it 'should deserialize the message into an object of the known type' do
          message = subject.deserialize_message(payload)
          expect(message).to be_a(A)
          expect(message.text).to eq('ABC')
        end
      end
      context 'when payload is for an unknown type' do
        let(:a) do
          A.new.tap do |a|
            a.text = 'ABC'
          end
        end
        let(:payload) do
          string = Oj.dump(a)
          JSON.load(string.sub('"^o":"A"', '"^o":"B"'))
        end
        let(:message) do
          EventQ::QueueMessage.new.tap do |m|
            m.content = payload
          end
        end
        let(:json) do
          Oj.dump(message)
        end
        it 'should deserialize the message into a Hash' do
          message = subject.deserialize_message(json)
          expect(message.content).to be_a(Hash)
          expect(message.content[:text]).to eq('ABC')
        end
      end
    end
    context 'when serialization provider is JSON_PROVIDER' do
      before do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::JSON_PROVIDER
      end
      let(:payload) do
        {
            content: { text: 'ABC' }
        }
      end
      let(:json) do
        JSON.dump(payload)
      end
      it 'should deserialize payload' do
        message = subject.deserialize_message(json)
        expect(message).to be_a(EventQ::QueueMessage)
        expect(message.content).to be_a(Hash)
        expect(message.content[:text]).to eq('ABC')
      end
      after do
        EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
    end
  end

  describe '#gc_flush' do
    context 'when the last gc_flush was made more than the gc_flush_interval length ago' do
      it 'should execute a GC flush' do
        allow(subject).to receive(:last_gc_flush).and_return(Time.now - 15)
        expect(GC).to receive(:start).once
        subject.gc_flush
      end
    end
    context 'when the last gc_flush was made NOT more than the gc_flush_interval length ago' do
      it 'should NOT execute a GC flush' do
        allow(subject).to receive(:last_gc_flush).and_return(Time.now - 5)
        expect(GC).not_to receive(:start)
        subject.gc_flush
      end
    end
  end

  context 'NonceManager' do
    context 'when a duplicate message is received' do
      let(:queue_message) { EventQ::QueueMessage.new }

      before do
        EventQ::NonceManager.configure(server: 'redis://redis:6379')
      end

      it 'should NOT process the message more than once' do
        event_type = 'queue.worker.nonce_check'
        subscriber_queue = EventQ::Queue.new
        subscriber_queue.name = 'queue.worker.noncecheck'
        #set queue retry delay to 0.5 seconds
        subscriber_queue.retry_delay = 500
        subscriber_queue.allow_retry = true

        qm = EventQ::RabbitMq::QueueManager.new
        q = qm.get_queue(channel, subscriber_queue)
        q.delete

        subscription_manager = EventQ::RabbitMq::SubscriptionManager.new({client: client})
        subscription_manager.subscribe(event_type, subscriber_queue)

        message = 'Hello World'

        eqclient = EventQ::RabbitMq::EventQClient.new({client: client, subscription_manager: subscription_manager})

        allow(eqclient).to receive(:new_message).and_return(queue_message)

        eqclient.raise_event(event_type, message)
        eqclient.raise_event(event_type, message)

        subject.configure(subscriber_queue, { sleep: 0 })

        received_count = 0

        subject.start(subscriber_queue, { client: client, wait: false, sleep: 0, thread_count: 1 }) do |content, args|
          received_count += 1
        end

        sleep(2)

        expect(received_count).to eq 1
      end

      after do
        EventQ::NonceManager.reset
      end
    end
  end

  describe '#call_on_error_block' do
    let(:error) { double }
    let(:message) { double }
    context 'when a block is specified' do
      let(:block) { double }
      before do
        subject.instance_variable_set(:@on_error_block, block)
        allow(block).to receive(:call)
      end
      it 'should execute the block' do
        expect(block).to receive(:call).with(error, message).once
        subject.call_on_error_block(error: error, message: message)
      end
    end
    context 'when a block is NOT specified' do
      let(:block) { nil }
      before do
        subject.instance_variable_set(:@on_error_block, block)
      end
      it 'should NOT execute the block' do
        expect(block).not_to receive(:call)
        subject.call_on_error_block(error: error, message: message)
      end
    end
  end

  describe '#call_on_retry_block' do
    let(:error) { double }
    let(:message) { double }
    context 'when a block is specified' do
      let(:block) { double }
      before do
        subject.instance_variable_set(:@on_retry_block, block)
        allow(block).to receive(:call)
      end
      it 'should execute the block' do
        expect(block).to receive(:call).with(error, message).once
        subject.call_on_retry_block(error: error, message: message)
      end
    end
    context 'when a block is NOT specified' do
      let(:block) { nil }
      before do
        subject.instance_variable_set(:@on_retry_block, block)
      end
      it 'should NOT execute the block' do
        expect(block).not_to receive(:call)
        subject.call_on_retry_block(error: error, message: message)
      end
    end
  end

  describe '#call_on_retry_exceeded_block' do
    let(:error) { double }
    let(:message) { double }
    context 'when a block is specified' do
      let(:block) { double }
      before do
        subject.instance_variable_set(:@on_retry_exceeded_block, block)
        allow(block).to receive(:call)
      end
      it 'should execute the block' do
        expect(block).to receive(:call).with(error, message).once
        subject.call_on_retry_exceeded_block(error: error, message: message)
      end
    end
    context 'when a block is NOT specified' do
      let(:block) { nil }
      before do
        subject.instance_variable_set(:@on_retry_exceeded_block, block)
      end
      it 'should NOT execute the block' do
        expect(block).not_to receive(:call)
        subject.call_on_retry_exceeded_block(error: error, message: message)
      end
    end
  end

end

class A
  attr_accessor :text
end