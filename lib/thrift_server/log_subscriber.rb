module ThriftServer
  class LogSubscriber
    include Concord.new(:logger)

    def rpc_ok(rpc, response, meta)
      logger.info("RPC: %s => OK (%.2fms)" % [
        rpc,
        meta.fetch(:latency)
      ])
    end

    def rpc_error(rpc, ex, meta)
      logger.info("RPC: %s => Error! %s (%.2fms)" % [
        rpc,
        ex.class.name,
        meta.fetch(:latency)
      ])

      logger.error ex
    end

    def rpc_exception(rpc, ex, meta)
      logger.info("RPC: %s => %s (%.2fms)" % [
        rpc,
        rpc.exception_name(ex),
        meta.fetch(:latency)
      ])
    end
  end
end
