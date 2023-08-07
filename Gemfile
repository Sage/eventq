source 'https://rubygems.org'

# Specify your gem's dependencies in eventq.gemspec
gemspec


gem 'json', '2.1.0'
gem 'redlock'

platforms :ruby do
  gem 'oj', '3.6.10'
  gem 'openssl', '2.1.1'
  gem 'bunny'
end

group :development, :test do
  gem 'pry-byebug', '< 3.10' # 3.10.0 requires Ruby >= 2.7
end
