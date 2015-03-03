require_relative 'test_helper'

class LogSubscriberTest < MiniTest::Unit::TestCase
  attr_reader :logger, :subscriber, :rpc

  # Make it easy to assert on a string line generated through the standard lib
  # progname & block syntax. This class will automatically yield the block and
  # concat it the mock receives a single line. This also ensures the block
  # is always executed, making sure it's free of errors
  class LogYielder
    include Concord.new(:log)

    def info(msg)
      if msg && block_given?
        log.info "#{msg} #{yield}"
      else
        log.info msg
      end
    end

    def error(msg)
      if msg && block_given?
        log.error "#{msg} #{yield}"
      else
        log.error msg
      end
    end
  end

  def setup
    @logger = mock
    @subscriber = ThriftServer::LogSubscriber.new LogYielder.new(logger)

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

  def test_server_thread_pool_change
    logger.expects(:info).with do |line|
      line =~ /\+1/
    end

    subscriber.server_thread_pool_change delta: 1
  end

  def test_server_connection_opened
    addr = stub ip_address: 'stub_ip', ip_port: 823

    logger.expects(:info).with do |line|
      line =~ /stub_ip/ && line =~ /823/
    end

    subscriber.server_connection_opened addr
  end

  def test_server_connection_closed
    addr = stub ip_address: 'stub_ip', ip_port: 823

    logger.expects(:info).with do |line|
      line =~ /stub_ip/ && line =~ /823/
    end

    subscriber.server_connection_closed addr
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
