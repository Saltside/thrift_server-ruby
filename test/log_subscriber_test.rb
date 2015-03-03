require_relative 'test_helper'

class LogSubscriberTest < MiniTest::Unit::TestCase
  attr_reader :logger, :subscriber, :rpc

  def setup
    @logger = mock
    @subscriber = ThriftServer::LogSubscriber.new logger

    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_server_start
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

  def test_rpc_ok_logs_result_to_info
    logger.expects(:info).with do |line|
      assert_match /foo/, line, 'RPC name not printed'
      assert_match /OK/, line
      assert_match /5.*ms/, line, 'Timing not printed'
    end

    subscriber.rpc_ok rpc, :response, latency: 5
  end

  def test_rpc_error_prints_result_and_trace
    error = StandardError.new

    logger.expects(:info).with do |line|
      assert_match /foo/, line, 'RPC name not printed'
      refute_match /OK/, line
      assert_match /StandardError/, line
      assert_match /5.*ms/, line, 'Timing not printed'
    end

    logger.expects(:error).with(error)

    subscriber.rpc_error rpc, error, latency: 5
  end

  def test_rpc_exception_prints_protocol_name
    rpc.exceptions = { exName: TestException }

    logger.expects(:info).with do |line|
      assert_match /foo/, line, 'RPC name not printed'
      refute_match /OK/, line
      assert_match /exName/, line
      assert_match /5.*ms/, line, 'Timing not printed'
    end

    subscriber.rpc_exception rpc, TestException.new(:message), latency: 5
  end
end
