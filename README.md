# EventQ

[![Maintainability](https://api.codeclimate.com/v1/badges/87205b497059e2733bdc/maintainability)](https://codeclimate.com/github/Sage/eventq/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/87205b497059e2733bdc/test_coverage)](https://codeclimate.com/github/Sage/eventq/test_coverage)

Welcome to EventQ.

EventQ is an event service bus framework for decoupling services and application processes.

Events are raised through the EventQ client and subscribers of the event types will be broadcast the event via a persistent queue for guaranteed delivery.
Existing solutions like ActiveJob work by assuming it posts directly to the queue provider.  EventQ takes advantage of systems that fanout notifications.
This allows a notification to have multiple subscribers of which one is a message that EventQ can directly process.

EventQ has a base layer which allows different queue implementations to be created abstracting the specific queue implementation details away from your application code.
EventQ comes with two default adapters, one for AWS SNS/SQS and another for RabbitMq (Fanout/Queue).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventq'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install eventq

## Usage

### Queue adapters
There are two adapters built into EventQ.  One supports AWS SNS/SQS and the other supports RabbitMq
In order to use the appropriate adapter you simply need to require the necessary file.

AWS
```ruby
require 'eventq/aws'
```

RabbitMq
```ruby
require 'eventq/rabbitmq'
```

### Queue

A subscription queue should be defined to receive any events raised for the subscribed event type.

**Attributes**

 - **allow_retry** [Bool] [Optional] [Default=false] This determines if the queue should allow processing failures to be retried.
 - **allow_retry_back_off** [Bool] [Optional] [Default=false] This is used to specify if failed messages that retry should incrementally backoff.
 - **allow_exponential_back_off** [Bool] [Optional] [Default=false] This is used to specify if failed messages that retry should expontentially backoff.
 - **retry_back_off_grace** [Int] [Optional] [Default=0] This is the number of times to allow retries without applying retry back off if enabled.
 - **dlq** [EventQ::Queue] [Optional] [Default=nil] A queue that will receive the messages which were not successfully processed after maximum number of receives by consumers. This is created at the same time as the parent queue.
 - **max_retry_attempts** [Int] [Optional] [Default=5] This is used to specify the max number of times an event should be allowed to retry before failing.
 - **max_receive_count** [Int] [Optional] [Default=30] The maximum number of times that a message can be received by consumers. When this value is exceeded for a message the message will be automatically sent to the Dead Letter Queue.
 - **max_retry_delay** [Int] [Optional] This is used to specify the max retry delay that should apply when allowing incremental back off.
 - **name** [String] [Required] This is the name of the queue, it must be unique.
 - **require_signature** [Bool] [Optional] [Default=false] This is used to specify if messages within this queue must be signed.
 - **retry_delay** [Int] [Optional] [Default=30000] This is used to specify the time delay in milliseconds before a failed message is re-added to the subscription queue.
 - **retry_back_off_weight** [Int] [Optional] [Default=1] Additional multiplier for the timeout backoff. Normally used when `retry_delay` is too small (eg: 30ms) in order to get meaningful backoff values.
 - **retry_jitter_ratio** [Int] [Optional] [Default=0] Amount of randomness for retry delays in percent to avoid a bulk of retries hitting again at the same time. 0% means no randomness, while 100% means full randomness. With full randomness, a random number between 0 and the calculated retry delay will be chosen for the delay.

**Example**

```ruby
# Create a queue that allows retries and accepts a maximum of 5 retries with a 20 second delay between retries.
class DataChangeAddressQueue < Queue
  def initialize
    @name = 'Data.Change.Address'
    @allow_retry = true
    @retry_delay = 20_000
    @max_retry_attempts = 5
  end
end
```

**Retry Strategies**

In distributed systems, it is expected for some events to fail.
Thankfully, those events can be put "on hold" and will be processed again after a given waiting time.
The attributes affecting your retry strategy the most are:
* `retry_delay` (base duration that events are waiting before being reprocessed)
* `max_receive_count` and `max_retry_attempts` (limiting how often an event can be seen / processed)
* `allow_retry`, `allow_retry_back_off` and `allow_exponential_back_off` (defining if retries are allowed and how duration between retries should be calculated)

If only `retry_delay` is set to `true`, while `allow_retry_back_off` and `allow_exponential_back_off` remain `false`, the duration between retries will be `retry_delay` each time ("fixed back off").
So there is a fixed duration between events, like in the example for `DataChangeAddressQueue` above.
With the configuration of that class, the event will be retried 5 times, with at least 20 seconds between retries.
Therefore we can calculate that the final retry will have happened after `retry_duration * max_retry_attempts`, which results in 100 seconds here.

If also `allow_retry_back_off` is set to `true`, the duration between retries will scale with the number of retries ("incremental back off").
So the first retry will happen after `retry_duration`, the second after `2 * retry_duration`, the third after `3 * retry_duration` and so on.
So the retries will be spread out further apart each time.
The last retry will be processed after `(max_retry_attempts * (max_retry_attempts + 1))/2 * retry_duration`.
So in the example above, it would result in 300 seconds until the last retry.

If also `allow_exponential_back_off` is set to `true`, the duration between retries will double each time ("exponential back off").
So the first retry will happen after `retry_duration`, the second after `2 * retry_duration`, the third after `4 * retry_duration` and so on.
The last retry will be processed after `(2^max_retry_attempts - 1) * retry_duration`.
So in the example above, it would result in 620 seconds until the last retry.

You can run experiments on your retry configuration using [plot_visibility_timeout.rb](https://github.com/Sage/eventq/blob/master/utilities/plot_visibility_timeout.rb), which will output the retry duration on each retry given your settings.


![Graph comparing back off strategies](images/back-off-strategy.png)

**Randomness**

By default, there will be no randomness in your retry strategy.
However, that means that with a fixed 20 second back off, many events overloading your service will all come back after exactly 20 seconds, overloading it again.
Therefore it can be useful to introduce randomness to your retry duration, so the events that initially hit the queue at the same time, are spread out when scheduling them for retry.

The attribute `retry_jitter_ratio` allows you to configure how much randomness ("jitter") is allowed for the retry duration.
Let's assume we have a `retry_duration = 20_000` (20 seconds).
Then the `retry_jitter_ratio` would have the following effect:
* 0 means no randomness, so retry duration of 20 seconds is used every time
* 20 means 20% randomness, so the duration will be randomly chosen between 80% to 100% of the value, i.e. between 16 to 20 seconds
* 50 means 50% randomness, i.e. between 10 to 20 seconds
* 80 means 80% randomness, i.e. between 4 to 20 seconds
* 100 means 100% randomness, i.e. between 0 to 20 seconds

In the graphs below you can see how adding 50% randomness can help avoid overloading the service.
In the first graph ("Fixed Retry Duration"), all failures are hitting the queue again after exactly 20 seconds.
This leads to only a couple of events to succeed, as the others fail due to too many concurrent requests running into locks etc.
However, in the second graph ("Randomised Retry Duration"), the events are randomnly spread out over the next 10 to 20 seconds.
This means less events hit the service concurrently, allowing it to succesfully process more events and processing all of the events in a shorter duration, reducing the overall load on the service.

![Graph showing that events overload the service repeatedly with fixed retry duration](images/fixed-retry-duration.png)

![Graph showing that events are spread out on retries when randomising retry duration](images/randomised-retry-duration.png)

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

    #create an instance of the queue definition
	queue = DateChangeAddressQueue.new

    #unsubscribe the queue definition
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

#### signature_provider

This is used to specify the signature provider that should be used for message signing.

> **Options:**
>
> - **SHA256** [Default] This is provider uses SHA256 to create message signatures.

#### signature_secret

This is used to specify the signature secret that should be used for message signing.

    #set the signature secret
    EventQ::Configuration.signature_secret = 'secret key'


### NonceManager

The NonceManager is used to prevent duplicate messages from being processed. Each event message that is raised is given a unique identifier, most message queue providers guarantee at least once delivery which may result in the message being delivered more than once. If your use case needs to enforce once only processing then
the NonceManager can be configured to prevent duplicate messages from being processed. (It is a distributed store that currently uses redis locks to ensure accuracy between scaled out workers)

#### configure

This method is called to configure the NonceManager, and must be called before starting the queue worker to be active.

**Params:**

 - **server** [String] [Required] This is redis server url.
 - **timeout** [Integer] [Optional] [Default=10000 (10 seconds)] This is the time in milliseconds that should be used for the initial nonce lock (this value should be low so as to not affect failure retries but long enough to cover the processing of the received message).
 - **lifespan** [Integer] [Optional] [Default=3600 (60 minutes)] This is the length of time the nonce should be kept for after processing of a message has completed.

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

## AWS Environment Variables

- **AWS_SQS_ENDPOINT** [String] [Optional] This is used to specify the endpoint of the SQS service to use.
- **AWS_SNS_ENDPOINT** [String] [Optional] This is used to specify the endpoint of the SNS service to use.

## Development

### Setup

After checking out the repo, run `bin/setup` to install dependencies.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.
To install this gem onto your local machine, run `bundle exec rake install`.

### Preparing the Docker images

Run the setup script of eventq to build the environment. This will create the `eventq` image.

    $ ./script/setup.sh

### Running the tests

By default, the full test suite will run against the mock AWS services defined in the docker-compose.yml file.  It also will run the tests for RabbitMq.

If you want to run the tests with AWS directly, you will need an AWS account. Put your credentials into the `.aws.env` file in the parent directory.
You will also need to comment out the AWS_* environment variables in the `docker-compose.yml` file

    $ cp ../.aws.env.template ../.aws.env
    $ vi ../.aws.env

Run the whole test suite:

    $ ./script/test.sh

You can run the specs that don't depend on an AWS account with:

    $ ./script/test.sh --tag ~integration

### Release new version

To release a new version, first update the version number in  the file [`EVENTQ_VERSION`](https://github.com/Sage/eventq/blob/master/EVENTQ_VERSION).
With that change merged to `master`, just [draft a new release](https://github.com/Sage/eventq/releases/new) with the same version you specified in `EVENTQ_VERSION`.
Use "Generate Release Notes" to generate details for this release.

This will create a git tag for the version and triggers the GitHub [Workflow to publish the new gem](https://github.com/Sage/eventq/actions/workflows/publish.yml) (defined in [publish.yml](https://github.com/Sage/eventq/blob/master/.github/workflows/publish.yml)) to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sage/eventq. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

EventQ is available as open source under the terms of the
[MIT licence](https://github.com/Sage/eventq/blob/master/LICENSE).

Copyright (c) 2018 Sage Group Plc. All rights reserved.
