require_relative 'test_helper'

class ServerMetricsMiddlewareTest < MiniTest::Unit::TestCase
  TestError = Class.new StandardError

  attr_reader :rpc

  def setup
    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_happy_path_call
    app = stub call: :result

    statsd = mock
    statsd.expects(:increment).with('rpc.incoming')
    statsd.expects(:increment).with('rpc.success')
    statsd.expects(:time).with('rpc.latency').yields.returns(:response)

    middleware = ThriftServer::ServerMetricsMiddleware.new(app, statsd)

    response = middleware.call rpc

    assert_equal :response, response
  end

  def test_rpc_raises_an_error
    app = stub
    app.stubs(:call).raises(TestError)

    statsd = mock
    statsd.expects(:increment).with('rpc.incoming')
    statsd.expects(:increment).with('rpc.error')
    statsd.expects(:increment).with('rpc.exception').never
    statsd.expects(:time).with('rpc.latency').yields.returns(:response)

    middleware = ThriftServer::ServerMetricsMiddleware.new(app, statsd)

    assert_raises TestError do
      middleware.call rpc
    end
  end

  def test_known_protocol_exceptions
    rpc.exceptions = [ TestError ]

    app = stub
    app.stubs(:call).raises(TestError)

    statsd = mock
    statsd.expects(:increment).with('rpc.incoming')
    statsd.expects(:increment).with('rpc.error').never
    statsd.expects(:increment).with('rpc.exception')
    statsd.expects(:time).with('rpc.latency').yields.returns(:response)

    middleware = ThriftServer::ServerMetricsMiddleware.new(app, statsd)

    assert_raises TestError do
      middleware.call rpc
    end
  end
end
