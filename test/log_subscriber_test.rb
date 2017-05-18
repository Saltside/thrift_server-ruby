require_relative 'test_helper'

class LogSubscriberTest < MiniTest::Unit::TestCase
  attr_reader :logger, :subscriber, :rpc

  def setup
    @logger = mock
    @subscriber = ThriftServer::LogSubscriber.new LogYielder.new(logger)

    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_thread_pool_server_pool_change_with_positive_delta
    logger.expects(:debug).with do |line|
      line =~ /\+1/
    end

    subscriber.thread_pool_server_pool_change delta: 1
  end

  def test_thread_pool_server_pool_change_with_negative_delta
    logger.expects(:debug).with do |line|
      line =~ /-1/
    end

    subscriber.thread_pool_server_pool_change delta: -1
  end

  def test_server_connection_opened
    addr = stub ip_address: 'stub_ip', ip_port: 823

    logger.expects(:debug).with do |line|
      line =~ /stub_ip/ && line =~ /823/
    end

    subscriber.server_connection_opened addr
  end

  def test_server_connection_closed
    addr = stub ip_address: 'stub_ip', ip_port: 823

    logger.expects(:debug).with do |line|
      line =~ /stub_ip/ && line =~ /823/
    end

    subscriber.server_connection_closed addr
  end

  def test_server_internal_error
    error = Thrift::TransportException.new
    addr = stub ip_address: 'stub_ip', ip_port: 823

    logger.expects(:info).with do |line|
      assert_includes line, addr.ip_address
      assert_includes line, addr.ip_port.to_s
      assert_match /Error/, line
      assert_includes line, error.class.name
    end

    logger.expects(:error).with(error)

    subscriber.server_internal_error addr, error
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
