require_relative 'test_helper'

class ThreadedServerTest < Minitest::Test
  include ServerTests

  attr_reader :service

  def setup
    @service = TestService
  end

  def build(*args, &block)
    ThriftServer.send :threaded, *args, &block
  end

  def test_is_threaded_server
    server = build service, stub

    assert_kind_of Thrift::ThreadedServer, server
  end

  def test_attaches_its_own_log_subscriber
    ThriftServer::ThreadedServer::LogSubscriber.expects(:new).with(:stdout).returns(:custom)

    server = build(service, stub) do |server|
      server.log :stdout
    end

    assert_includes server.publisher, :custom
  end

  def test_start_up_logging
    logger = mock
    subscriber = ThriftServer::ThreadedServer::LogSubscriber.new LogYielder.new(logger)

    server = stub({
      port: 9999,
      transport: 'StubTransport',
      protocol: 'StubProtocol'
    })

    logger.expects(:info).with do |line|
      line =~ /9999/
    end

    logger.expects(:info).with do |line|
      line =~ /StubTransport/
    end

    logger.expects(:info).with do |line|
      line =~ /StubProtocol/
    end

    subscriber.server_start server
  end
end
