# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
version = File.read(File.expand_path("EVENTQ_VERSION", __dir__)).strip

Gem::Specification.new do |spec|
  spec.name          = "eventq"
  spec.version       = version
  spec.authors       = ["SageOne"]
  spec.email         = ["sageone@sage.com"]

  spec.summary       = 'This is EventQ system'
  spec.description   = 'This is EventQ system'
  spec.homepage      = "https://github.com/sage/eventq"
  spec.license       = "MIT"

  spec.files         = ["README.md"] + Dir.glob("{bin,lib}/**/**/**")
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'shoulda-matchers'

  spec.add_dependency 'aws-sdk', '~> 2.0'
  spec.add_dependency 'class_kit'
  spec.add_dependency 'redlock'
  spec.add_dependency 'openssl'
  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'activesupport', '~> 4'

  if RUBY_PLATFORM =~ /java/
    spec.platform = 'java'
    spec.add_dependency 'march_hare'
  else
    spec.add_dependency 'oj'
    spec.add_dependency 'bunny'
  end
end
