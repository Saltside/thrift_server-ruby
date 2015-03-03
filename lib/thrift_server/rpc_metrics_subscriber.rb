module ThriftServer
  class RpcMetricsSubscriber
    include Concord.new(:statsd)

    def rpc_incoming(rpc)
      statsd.increment "rpc.#{rpc}.incoming"
    end

    def rpc_ok(rpc, response, meta)
      statsd.increment "rpc.#{rpc}.success"
      statsd.timing "rpc.#{rpc}.latency", meta.fetch(:latency)
    end

    def rpc_exception(rpc, ex, meta)
      statsd.increment "rpc.#{rpc}.exception"
      statsd.increment "rpc.#{rpc}.exception.#{rpc.exception_name(ex)}"
      statsd.timing "rpc.#{rpc}.latency", meta.fetch(:latency)
    end

    def rpc_error(rpc, ex, meta)
      statsd.increment "rpc.#{rpc}.error"
      statsd.timing "rpc.#{rpc}.latency", meta.fetch(:latency)
    end
  end
end
