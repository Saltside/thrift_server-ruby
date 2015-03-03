require 'bundler/setup'
require 'thrift_server'

require 'stringio'
require 'logger-better'

require 'minitest/autorun'
require 'mocha/mini_test'

TestError = Class.new StandardError

class FakeStatsd
  def time(*)
    yield
  end

  def increment(*)

  end
end

class NullErrorTracker
  def track(*)

  end
end

TestException = Class.new Thrift::Exception

class SimulatedResult
  FIELDS = {
    'EXCEPTION' => { name: 'test', class: TestException }
  }
end

module GenericService
  class Processor
    include Thrift::Processor

    def process_ping(*args)
      @handler.ping(*args)
    end
  end

  class Ping_result
    FIELDS = {
      'EXCEPTION' => { name: 'ping_test', class: TestException }
    }
  end
end

module TestService
  class Processor < GenericService::Processor
    include Thrift::Processor

    def process_getItems(*args)
      @handler.getItems(*args)
    end
  end

  class GetItems_result
    FIELDS = {
      'EXCEPTION' => { name: 'getItems_test', class: TestException }
    }
  end
end

# Monkey patch attr readers to test various server settings
module Thrift
  class ServerSocket
    attr_reader :port
  end

  class ThreadPoolServer
    attr_reader :server_transport, :transport_factory, :protocol_factory
    def threads
      @thread_q.max
    end

    def port
      server_transport.port
    end
  end
end
