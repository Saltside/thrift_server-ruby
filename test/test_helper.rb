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

def Processor(*rpcs)
  Class.new do
    def initialize(handler)
      @handler = handler
    end

    rpcs.each do |method_name|
      define_method "process_#{method_name}" do |*args|
        # nothing to do, this is just a stub to create objects inline
        # with the generate thrift processors
        @handler.send method_name, *args
      end
    end
  end
end
