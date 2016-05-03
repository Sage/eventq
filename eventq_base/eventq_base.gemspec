# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eventq_base/version'

Gem::Specification.new do |spec|
  spec.name          = "eventq_base"
  spec.version       = EventqBase::VERSION
  spec.authors       = ["vaughanbrittonsage"]
  spec.email         = ["vaughanbritton@gmail.com"]

  spec.summary       = 'This gem contains the base classes and contracts required by any eventq implementations.'
  spec.description   = 'This gem contains the base classes and contracts required by any eventq implementations.'
  spec.homepage      = "https://github.com/vaughanbrittonsage/eventq"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{bin,lib}/**/**/**")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
end
