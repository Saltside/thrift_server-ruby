require_relative 'test_helper'

class LoggingMiddlewareTest < MiniTest::Unit::TestCase
  attr_reader :output, :logger, :rpc

  def setup
    @output = StringIO.new
    @logger = Logger.new output
    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_logs_incoming_rpcs_names
    app = stub call: :result

    middleware = ThriftServer::LoggingMiddleware.new(app, logger)

    middleware.call rpc

    assert_logged output, 'INFO'
    assert_logged output, rpc.name
  end

  def test_logs_errors
    app = stub
    app.stubs(:call).raises(TestError)

    middleware = ThriftServer::LoggingMiddleware.new(app, logger)

    assert_raises TestError do
      middleware.call rpc
    end

    assert_logged output, 'ERROR'
    assert_logged output, 'TestError'
  end

  private
  def assert_logged(log, text)
    log.rewind
    assert log.read.include?(text.to_s), "#{text} not logged"
  end
end
