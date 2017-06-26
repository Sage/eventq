# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eventq_rabbitmq/version'

Gem::Specification.new do |spec|
  spec.name          = "eventq_rabbitmq"
  spec.version       = EventqRabbitmq::VERSION
  spec.authors       = ["vaughanbrittonsage"]
  spec.email         = ["vaughanbritton@gmail.com"]

  spec.summary       = 'This is the rabbitmq implementation for EventQ'
  spec.description   = 'This is the rabbitmq implementation for EventQ'
  spec.homepage      = "https://github.com/vaughanbrittonsage/eventq"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{bin,lib}/**/**/**")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'

  spec.add_dependency 'eventq_base', '~> 1.15'

  if RUBY_PLATFORM =~ /java/
    spec.platform = 'java'
    spec.add_dependency 'march_hare'
  else
    spec.add_dependency 'bunny'
  end
end
