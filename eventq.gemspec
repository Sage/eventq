# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
version = File.read(File.expand_path("EVENTQ_VERSION", __dir__)).strip

Gem::Specification.new do |spec|
  spec.name          = "eventq"
  spec.version       = version
  spec.authors       = ["SageOne"]
  spec.email         = ["sageone@sage.com"]

  spec.description = spec.summary = 'EventQ is a pub/sub system that uses async notifications and message queues'
  spec.homepage      = "https://github.com/sage/eventq"
  spec.license       = "MIT"
  spec.files         = ["README.md"] + Dir.glob("{bin,lib}/**/**/**")
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'activesupport', '~> 6'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'byebug', '~> 11.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.9'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'shoulda-matchers'
  spec.add_development_dependency 'simplecov', '< 0.18.0'
  spec.add_development_dependency 'debug'

  spec.add_dependency 'aws-sdk-core'
  spec.add_dependency 'aws-sdk-sns'
  spec.add_dependency 'aws-sdk-sqs'
  spec.add_dependency 'bunny'
  spec.add_dependency 'class_kit'
  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'oj'
  spec.add_dependency 'openssl'
  spec.add_dependency 'redlock'
  spec.add_dependency 'connection_pool'
end
