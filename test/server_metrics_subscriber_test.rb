require_relative 'test_helper'

class ServerMetricsSubscriberTest < MiniTest::Unit::TestCase
  TestError = Class.new StandardError

  attr_reader :subscriber, :rpc, :statsd

  def setup
    @statsd = mock
    @subscriber = ThriftServer::ServerMetricsSubscriber.new statsd

    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_server_connection_opened
    statsd.expects(:gauge).with('server.pool.active', '+1')
    subscriber.server_connection_opened :addr
  end

  def test_server_connection_closed
    statsd.expects(:gauge).with('server.pool.active', '-1')
    subscriber.server_connection_closed :addr
  end

  def test_server_thread_pool_change_with_positive_delta
    statsd.expects(:gauge).with('server.pool.size', '+1')
    subscriber.server_thread_pool_change delta: 1
  end

  def test_server_thread_pool_change_with_negative_delta
    statsd.expects(:gauge).with('server.pool.size', '-1')
    subscriber.server_thread_pool_change delta: -1
  end

  def test_rpc_incoming
    statsd.expects(:increment).with('rpc.incoming')

    subscriber.rpc_incoming rpc
  end

  def test_rpc_ok
    statsd.expects(:increment).with('rpc.success')
    statsd.expects(:timing).with('rpc.latency', 5)

    subscriber.rpc_ok rpc, :response, latency: 5
  end

  def test_exception
    statsd.expects(:increment).with('rpc.exception')
    statsd.expects(:timing).with('rpc.latency', 5)

    subscriber.rpc_exception rpc, :response, latency: 5
  end

  def test_error
    statsd.expects(:increment).with('rpc.error')
    statsd.expects(:timing).with('rpc.latency', 5)

    subscriber.rpc_error rpc, :response, latency: 5
  end
end
