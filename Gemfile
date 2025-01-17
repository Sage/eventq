# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in eventq.gemspec
gemspec

gem 'json', '~> 2'

platforms :ruby do
  gem 'bunny'
  gem 'oj', '3.12.3' # 3.13.0 breaks the specs
  gem 'openssl'
  gem 'rexml'
end
