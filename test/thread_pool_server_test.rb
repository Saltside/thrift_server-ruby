require_relative 'test_helper'

class ThreadPoolSeverTest < Minitest::Test
  include ServerTests

  attr_reader :service

  def setup
    @service = TestService
  end

  def build(*args, &block)
    ThriftServer.send :thread_pool, *args, &block
  end

  def test_returns_thread_pool_server
    server = build service, stub

    assert_kind_of Thrift::ThreadPoolServer, server
  end

  def test_defaults_to_25_threads
    server = build service, stub

    assert_equal 25, server.threads
  end

  def test_accepts_threads_option
    server = build(service, stub, {
      threads: 8
    })

    assert_equal 8, server.threads
  end

  def test_attaches_its_own_log_subscriber
    ThriftServer::ThreadPoolServer::LogSubscriber.expects(:new).with(:stdout).returns(:custom)

    server = build(service, stub) do |server|
      server.log :stdout
    end

    assert_includes server.publisher, :custom
  end

  def test_start_up_logging
    logger = mock
    subscriber = ThriftServer::ThreadPoolServer::LogSubscriber.new LogYielder.new(logger)

    server = stub({
      port: 9999,
      threads: 30,
      transport: 'StubTransport',
      protocol: 'StubProtocol'
    })

    logger.expects(:info).with do |line|
      line =~ /9999/
    end

    logger.expects(:info).with do |line|
      line =~ /30/
    end

    logger.expects(:info).with do |line|
      line =~ /StubTransport/
    end

    logger.expects(:info).with do |line|
      line =~ /StubProtocol/
    end

    subscriber.server_start server
  end

  def test_attaches_own_metrics_subcriber
    ThriftServer::ThreadPoolServer::MetricsSubscriber.expects(:new).with(:statsd).returns(:custom)

    server = build(service, stub) do |server|
      server.metrics :statsd
    end

    assert_includes server.publisher, :custom
  end

  def test_thread_pool_server_pool_change_with_positive_delta
    statsd = mock
    subscriber = ThriftServer::ThreadPoolServer::MetricsSubscriber.new statsd

    statsd.expects(:gauge).with('server.pool.size', '+1')
    subscriber.thread_pool_server_pool_change delta: 1
  end

  def test_thread_pool_server_pool_change_with_negative_delta
    statsd = mock
    subscriber = ThriftServer::ThreadPoolServer::MetricsSubscriber.new statsd

    statsd.expects(:gauge).with('server.pool.size', '-1')
    subscriber.thread_pool_server_pool_change delta: -1
  end
end
