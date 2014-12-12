require_relative 'test_helper'

class MetricsMiddlewareTest < MiniTest::Unit::TestCase
  attr_reader :rpc

  def setup
    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_times_the_rpc
    app = stub call: :result

    statsd = Class.new FakeStatsd do
      attr_reader :timer

      def time(*args)
        @timer = args.first
        yield
      end
    end.new

    middleware = ThriftServer::MetricsMiddleware.new(app, statsd)

    middleware.call rpc

    assert statsd.timer, 'Timer not recorded'
    assert_equal rpc.name, statsd.timer
  end

  def test_increments_a_counter_on_failed_rpcs
    app = stub
    app.stubs(:call).raises(TestError)

    statsd = Class.new FakeStatsd do
      attr_reader :counter

      def increment(*args)
        @counter = args.first
      end
    end.new

    middleware = ThriftServer::MetricsMiddleware.new(app, statsd)

    assert_raises TestError do
      middleware.call rpc
    end

    assert statsd.counter, 'Counter not updated'
    assert_equal 'errors', statsd.counter
  end
end
