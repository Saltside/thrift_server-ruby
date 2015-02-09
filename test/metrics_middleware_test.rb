require_relative 'test_helper'

class MetricsMiddlewareTest < MiniTest::Unit::TestCase
  TestError = Class.new StandardError

  attr_reader :rpc

  def setup
    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_happy_path_call
    app = stub call: :result

    statsd = mock
    statsd.expects(:increment).with('thrift.rpc.incoming')
    statsd.expects(:increment).with('thrift.rpc.success')
    statsd.expects(:time).with('thrift.rpc.latency').yields.returns(:response)

    middleware = ThriftServer::MetricsMiddleware.new(app, statsd)

    response = middleware.call rpc

    assert_equal :response, response
  end

  def test_rpc_raises_an_error
    app = stub
    app.stubs(:call).raises(TestError)

    statsd = mock
    statsd.expects(:increment).with('thrift.rpc.incoming')
    statsd.expects(:increment).with('thrift.rpc.error')
    statsd.expects(:time).with('thrift.rpc.latency').yields.returns(:response)

    middleware = ThriftServer::MetricsMiddleware.new(app, statsd)

    assert_raises TestError do
      middleware.call rpc
    end
  end
end
