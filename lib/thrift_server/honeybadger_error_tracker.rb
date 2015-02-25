class ThriftServer
  class HoneybadgerErrorTracker
    def initialize(client = Honeybadger)
      @client = client
    end

    def track(rpc, error)
      @client.notify_or_ignore(error, {
        context: {
          rpc: {
            name: rpc.name,
            args: rpc.args.inspect
          }
        }
      })
    end
  end
end
