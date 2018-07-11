# EventQ [AWS]

Welcome to EventQ. This gem contains the AWS implementations of the EventQ framework components.

## Installation

Add this line to your application:

```ruby
require 'eventq/aws'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Preparing the Docker images

Run the setup script of eventq_aws to build the environment. This will create the `eventq/aws` image.

    $ cd script
    $ ./setup.sh

### Running the tests

By default, the full test suite will run against the mock AWS services defined in the docker-compose.yml file.

If you want to run the tests with AWS directly, you will need an AWS account. Put your credentials into the `.aws.env` file in the parent directory.

    $ cp ../.aws.env.template ../.aws.env
    $ vi ../.aws.env

Run the whole test suite:

    $ cd script
    $ ./test.sh

You can run the specs that don't depend on an AWS account with:

    $ cd script
    $ ./test.sh --tag ~integration

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sage/eventq. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

