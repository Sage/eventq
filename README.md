# EventQ

Welcome to EventQ. 

EventQ is an event service bus framework for decoupling services and application processes.

Events are raised through the EventQ client and subscribers of the event types will be broadcast the event via a persistent queue for guaranteed delivery.

EventQ has a base layer which allows different queue implementations to be created abstracting the specific queue implementation details away from your application code. (E.g RabbitMq / AWS SQS etc.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventq_base'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eventq_base

## Usage

### Queue

A subscription queue should be defined to receive any events raised for the subscribed event type.

**Attributes**

 - **name** [String] [Required] This is the name of the queue, it must be unique.
 - **allow_retry** [Bool] [Optional] [Default=false] This determines if the queue should allow processing failures to be retried.
 - **retry_delay** [Int] [Optional] [Default=30000] This is used to specify the time delay in milliseconds before a failed message is re-added to the subscription queue. 
 - **max_retry_attempts** [Int] [Optional] [Default=5] This is used to specify the max number of times an event should be allowed to retry before failing.

**Example**

    #create a queue that allows retries and accepts a maximum of 3 retries with a 20 second delay between retries.
    class DataChangeAddressQueue < Queue
	    def initialize
		    @name = 'Data.Change.Address'
		    @allow_retry = true
		    @retry_delay = 20000
		    @max_retry_attempts = 3
		end
	end

### SubscriptionManager

In order to receive events within a subscription queue it must subscribe to the type of the event it should receive.

#### #subscribe

This method is called to subscribe a queue to an event type.

**Params:**

 - **event_type** [String] [Required] This is the unique name of the event type to subscribe to.
 - **queue** [Queue] [Required] This is the queue definition object that represents the queue to subscribe.

**Example**

	#create an instant of the queue definition
	queue = DateChangeAddressQueue.new
	
    #subscribe the queue definition to an event type
    subscription_manager.subscribe('Data:Change:Address', queue)

#### #unsubscribe

This method is called to unsubscribe a queue.

**Params:**

 - **queue** [Queue] [Required] This is the queue definition object that represents the queue to unsubscribe.

**Example**

    #create an instant of the queue definition
	queue = DateChangeAddressQueue.new
	
    #subscribe the queue definition to an event type
    subscription_manager.unsubscribe(queue)


### QueueWorker

The queue worker is used to process subscribed events from a subscription queue. The QueueWorker uses threads and is capable of processing subscribed events in parallel.

#### #on_retry_exceeded

The on_retry_exceeded method allows you to specify a block that should execute whenever an event fails to process and exceeds the maximum allowed retry attempts specified by the queue. The event object passed to the block is a **[QueueMessage]** object.

**Example**

    worker.on_retry_exceeded do |event|
		....
		#Do something with the failed event
		....
	end
	
#### #on_retry

The on_retry method allows you to specify a block that should execute whenever an event fails to process and is retried. The event object passed to the block is a **[QueueMessage]** object, and the abort arg is a Boolean that specifies if the message was aborted (true or false).


[NOTE: The message will be automatically retried so no manual action is required, this is to allow additional logging etc to be performed]

**Example**

    worker.on_retry do |event, abort|
		....
		#Do something with the failed event
		....
	end
	
#### #on_error

The on_error method allows you to specify a block that should execute whenever an unhandled error occurs with the worker. The could be communication failures with the queue etc.

**Example**

    worker.on_error do |error|
		....
		#Do something with the error
		....
	end

#### #start

The start method is used to specify a block to process received events and start the worker.

**Params:**

 - **queue** [Queue] [Required] This is the queue definition for the subscription queue this worker should process.
 - **options** [Hash] [Optional] This is an options hash to configure the queue worker.

> **Options:**
>
> - **:fork_count** [Int] [Optional] [Default=1] This is the number of process forks that the queue worker will use to process events in parallel (Additional forks should be added to take advantage of multi core CPU's).
>
> - **:thread_count** [Int] [Optional] [Default=5] This is the number of threads that the queue worker should use to process events in parallel.
>
> - **:sleep** [Number] [Optional] [Default=15] This is the number of seconds a thread should sleep before attempting to request another event from the subscription queue when no event has been received.
>
> - **:wait** [Bool] [Optional] This is used to specify that the start method should block the calling thread and wait until all parallel threads have finished. (This can be used to ensure that the background process running the worker does not exit).
> 
> **Block arguments:**
> - **content** [Object] This is the content of the received event.
>
> - **type** [String] This is the type of the received event.
>
> - **retry_attempts** [Int] This is the number of times the received event has been retried.

**Example**

    #start the queue worker
    worker.start(queue, {:thread_count => 8, :sleep => 30 }) do |content,type,retry_attempts|
    ....
    #add event processing code here
    ....
    end

#### #stop

This method is called to stop the QueueWorker and all threads.

> **Note:** This is only available when the :wait option has not been specified for the **#start** method.

**Example**

    #stop the worker
    worker.stop

### QueueMessage

The **[QueueMessage]** is used internally to represent an event within the various queues. It is also returned as a parameter to the #on_retry_exceeded block of a [QueueWorker].

**Attributes:**

 - **type** [String] This is the type of the event contained.
 - **content** [Object] This is the event content.
 - **retry_attempts** [Int] This is the number of times this event message has been retried.
 - **created** [DateTime] this is when the event was initial raised.
 
### Configuration
 
The `EventQ::Configuration` class allows global configuration options to be specified.
 
#### serialization_provider

This is used to specify the serialization provider that should be used for event serialization & deserialization.

> **Options:**
>
> - **OJ_PROVIDER** [Default] This is a serialization provider that uses the 'oj' gem to handle serialization & deserialization.
> - **JSON_PROVIDER** This is a serialization provider that uses the 'json' gem to handle serialization & deserialization.

    #set the serialization provider configuration to the OJ_PROVIDER
    EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
..

    #set the serialization provider configuration to the JSON_PROVIDER
    EventQ::Configuration.serialization_provider = EventQ::SerializationProviders::JSON_PROVIDER
    
### NonceManager

The NonceManager is used to prevent duplicate messages from being processed. Each event message that is raised is given a unique identifier, most message queue providers guarantee at least once delivery which may result in the message being delivered more than once. If your use case needs to enforce once only processing then 
the NonceManager can be configured to prevent duplicate messages from being processed. (It is a distributed store that currently uses redis locks to ensure accuracy between scaled out workers)

#### configure

This method is called to configure the NonceManager, and must be called before starting the queue worker to be active.

**Params:**

 - **server** [String] [Required] This is redis server url.
 - **timeout** [Integer] [Optional] [Default=10000 (10 seconds)] This is the time in milliseconds that should be used for the initial nonce lock (this value should be low so as to not affect failure retries but long enough to cover the processing of the received message).
 - **lifespan** [Integer] [Optional] [Default=3600000 (60 minutes)] This is the length of time the nonce should be kept for after processing of a message has completed.

**Example**

    EventQ::NonceManager.configure(server: 'redis://127.0.0.1:6379')
    

### Namespace

This attribute is used to specify a namespace for all events and queues to be created within.

**Example**

    EventQ.namespace = 'development'

### StatusChecker

The status checker is used to verify the status of a queue or event type (topic/exchange).

####queue?

This method is called to verify connection to a queue.

**Params:**

 - **queue** [EventQ::Queue] [Required] This is a queue definition object.
 
**Return** [Boolean] (True or False)


**Example**

    available = status_checker.queue?(queue)
    
####event_type?

This method is called to verify connection to an event_type (topic/exchange).

**Params:**

- **event_type** [String] [Required] This is the unique identifier of the event_type.

**Return** [Boolean] (True or False)


**Example**

    available = status_checker.event_type?(event_type)
    


## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sage/eventq. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

