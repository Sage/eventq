source 'https://rubygems.org'

# Specify your gem's dependencies in eventq.gemspec
gemspec


gem 'json', '1.8.3'
gem 'redlock'

platforms :ruby do
  gem 'oj', '2.15.0'
  gem 'pry'
  gem 'openssl', '2.0.4'
  gem 'bunny'
end

platforms :jruby do
  gem 'pry-debugger-jruby'
  gem 'jruby-openssl'
  gem 'march_hare'
end
