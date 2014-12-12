require 'bundler/setup'
require 'thrift_server'

require 'benchmark/ips'
require 'logger-better'
require 'middleware'

class NullStatsd
  def time(*) ; yield ; end
  def increment(*) ; end
end

class NullErrorTracker
  def track(*) ; end
end

class FakeProcessor
  include Concord.new(:handler)

  def process_someRPC
    handler.someRPC
  end
end

class FakeHandler
  def someRPC
    :response
  end
end

Benchmark.ips do |x|
  x.time = 20
  x.warmup = 5

  processor = ThriftServer.wrap(FakeProcessor, {
    logger: NullLogger.new,
    statsd: NullStatsd.new,
    error_tracker: NullErrorTracker.new
  })

  server = processor.new FakeHandler.new

  x.report("server") { server.process_someRPC }
end
