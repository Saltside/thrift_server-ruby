require_relative 'test_helper'

class RpcMetricsSubscriberTest < MiniTest::Unit::TestCase
  TestError = Class.new StandardError

  attr_reader :subscriber, :rpc, :statsd

  def setup
    @statsd = mock
    @subscriber = ThriftServer::RpcMetricsSubscriber.new statsd

    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_rpc_incoming
    statsd.expects(:increment).with('rpc.foo.incoming')

    subscriber.rpc_incoming rpc
  end

  def test_rpc_ok
    statsd.expects(:increment).with('rpc.foo.success')
    statsd.expects(:timing).with('rpc.foo.latency', 5)

    subscriber.rpc_ok rpc, :response, latency: 5
  end

  def test_rpc_exception
    rpc.exceptions = { test: TestException }

    statsd.expects(:increment).with('rpc.foo.exception')
    statsd.expects(:increment).with('rpc.foo.exception.test')
    statsd.expects(:timing).with('rpc.foo.latency', 5)

    subscriber.rpc_exception rpc, TestException.new(:placeholder), latency: 5
  end

  def test_rpc_error
    statsd.expects(:increment).with('rpc.foo.error')
    statsd.expects(:timing).with('rpc.foo.latency', 5)

    subscriber.rpc_error rpc, :response, latency: 5
  end
end
