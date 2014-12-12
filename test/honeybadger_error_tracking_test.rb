require_relative 'test_helper'

class HoneybadgerErrorTrackerTest < MiniTest::Unit::TestCase
  def test_logs_according_to_honeybadger_api
    client = mock
    client.expects(:notify_or_ignore).with(:error)

    tracker = ThriftServer::HoneybadgerErrorTracker.new client

    tracker.track :rpc, :error
  end
end
