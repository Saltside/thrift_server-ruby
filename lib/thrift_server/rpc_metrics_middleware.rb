class ThriftServer
  class RpcMetricsMiddleware
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.increment "rpc.#{rpc.name}.incoming"

      response = statsd.time "rpc.#{rpc.name}.latency" do
        app.call rpc
      end

      statsd.increment "rpc.#{rpc.name}.success"

      response
    rescue => ex
      if rpc.protocol_exception? ex
        statsd.increment "rpc.#{rpc.name}.exception"
        statsd.increment "rpc.#{rpc.name}.exception.#{rpc.exception_name(ex)}"
      else
        statsd.increment "rpc.#{rpc.name}.error"
      end

      raise ex
    end
  end
end
