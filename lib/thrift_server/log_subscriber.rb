module ThriftServer
  class LogSubscriber
    include Concord.new(:logger)

    def thread_pool_server_pool_change(meta)
      logger.debug :server do
        "Thread pool change: %+d" % [ meta.fetch(:delta) ]
      end
    end

    def server_connection_opened(addr)
      logger.debug :server do
        "%s:%d connected" % [
          addr.ip_address,
          addr.ip_port
        ]
      end
    end

    def server_connection_closed(addr)
      logger.debug :server do
        "%s:%d disconnected" % [
          addr.ip_address,
          addr.ip_port
        ]
      end
    end

    def server_internal_error(addr, ex)
      logger.info :server do
        "%s:%d => Error! %s" % [
          addr.ip_address,
          addr.ip_port,
          ex.class.name
        ]
      end

      logger.error ex
    end

    def rpc_ok(rpc, response, meta)
      logger.info :processor do
        "%s => OK (%.2fms)" % [
          rpc.name,
          meta.fetch(:latency)
        ]
      end
    end

    def rpc_error(rpc, ex, meta)
      logger.info :processor do
        "%s => Error! %s (%.2fms)" % [
          rpc.name,
          ex.class.name,
          meta.fetch(:latency)
        ]
      end

      logger.error ex
    end

    def rpc_exception(rpc, ex, meta)
      logger.info :processor do
        "%s => %s (%.2fms)" % [
          rpc.name,
          rpc.exception_name(ex),
          meta.fetch(:latency)
        ]
      end
    end
  end
end
