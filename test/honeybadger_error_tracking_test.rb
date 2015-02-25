require_relative 'test_helper'

class HoneybadgerErrorTrackerTest < MiniTest::Unit::TestCase
  def test_logs_according_to_honeybadger_api
    rpc = ThriftServer::RPC.new :name, [ :args ]

    client = mock
    client.expects(:notify_or_ignore).with(:error, context: {
      rpc: {
        name: rpc.name,
        args: rpc.args.inspect
      }
    })

    tracker = ThriftServer::HoneybadgerErrorTracker.new client

    tracker.track rpc, :error
  end
end
