# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thrift_server/version'

Gem::Specification.new do |spec|
  spec.name          = "thrift_server"
  spec.version       = ThriftServer::VERSION
  spec.authors       = ["ahawkins"]
  spec.email         = ["adam@saltside.se"]
  spec.summary       = %q{Encapsulate error handling, logging, and metrics for thrift servers}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/saltside/thrift_server-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "statsd-ruby"
  spec.add_dependency "middleware"
  spec.add_dependency "concord"
  spec.add_dependency "thrift"
  spec.add_dependency "thrift-validator"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "logger-better"
  spec.add_development_dependency "benchmark-ips"
end
