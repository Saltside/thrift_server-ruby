module ThriftServer
  class ServerMetricsSubscriber
    include Concord.new(:statsd)

    def server_connection_opened(*)
      statsd.gauge 'server.connection.active', '+1'
    end

    def server_connection_closed(*)
      statsd.gauge 'server.connection.active', '-1'
    end

    def rpc_incoming(rpc)
      statsd.increment 'rpc.incoming'
    end

    def rpc_ok(rpc, response, meta)
      statsd.increment 'rpc.success'
      statsd.timing 'rpc.latency', meta.fetch(:latency)
    end

    def rpc_exception(rpc, ex, meta)
      statsd.increment 'rpc.exception'
      statsd.timing 'rpc.latency', meta.fetch(:latency)
    end

    def rpc_error(rpc, ex, meta)
      statsd.increment 'rpc.error'
      statsd.timing 'rpc.latency', meta.fetch(:latency)
    end
  end
end
