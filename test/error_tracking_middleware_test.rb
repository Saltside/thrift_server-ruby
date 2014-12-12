require_relative 'test_helper'

class ErrorTrackingMiddlewareTest < MiniTest::Unit::TestCase
  attr_reader :rpc

  def setup
    @rpc = ThriftServer::RPC.new :foo, :bar
  end

  def test_logs_errors
    error = TestError.new

    logger = mock
    logger.expects(:track).with(rpc, error)

    app = stub
    app.stubs(:call).raises(error)

    middleware = ThriftServer::ErrorTrackingMiddleware.new app, logger

    assert_raises TestError do
      middleware.call rpc
    end
  end
end
