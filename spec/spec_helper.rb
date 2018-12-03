# frozen_string_literal: true

require 'pry'
require 'oj'

require 'simplecov'
SimpleCov.start do
  add_filter ['spec/']
end
puts 'required simplecov'
require 'shoulda-matchers'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
  end
end

require_relative '../lib/eventq'
require_relative '../lib/eventq/rabbitmq'
require_relative '../lib/eventq/aws'

RSpec.configure do |config|

  config.before(:each) do

  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.example_status_persistence_file_path = 'spec_run.txt'

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.disable_monkey_patching!

  config.warnings = false

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10

  config.order = :defined

  Kernel.srand config.seed
end
