class ThriftServer
  class RpcMetricsMiddleware
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.increment "thrift.#{rpc.name}.incoming"

      response = statsd.time "thrift.#{rpc.name}.latency" do
        app.call rpc
      end

      statsd.increment "thrift.#{rpc.name}.success"

      response
    rescue => ex
      statsd.increment "thrift.#{rpc.name}.error"
      raise ex
    end
  end
end
