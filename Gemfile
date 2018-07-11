source 'https://rubygems.org'

# Specify your gem's dependencies in eventq.gemspec
gemspec


gem 'json', '1.8.5'
gem 'redlock'

platforms :ruby do
  gem 'oj', '2.16.1'
  gem 'pry'
  gem 'openssl', '2.0.4'
  gem 'bunny'
end

platforms :jruby do
  gem 'pry-debugger-jruby'
  gem 'jruby-openssl'
  gem 'march_hare'
end
