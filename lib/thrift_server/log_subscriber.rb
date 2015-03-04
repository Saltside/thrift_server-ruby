module ThriftServer
  class LogSubscriber
    include Concord.new(:logger)

    def server_start(server)
      logger.info 'server' do
        "Started on port %d" % [ server.port ]
      end

      logger.info 'server' do
        "-> Threads: %d" % [ server.threads ]
      end

      logger.info 'server' do
        "-> Transport: %s" % [ server.transport ]
      end

      logger.info 'server' do
        "-> Protocol: %s" % [ server.protocol ]
      end
    end

    def server_thread_pool_change(meta)
      logger.debug 'server' do
        "Thread pool change: %+d" % [ meta.fetch(:delta) ]
      end
    end

    def server_connection_opened(addr)
      logger.debug 'server' do
        "%s:%d connected" % [
          addr.ip_address,
          addr.ip_port
        ]
      end
    end

    def server_connection_closed(addr)
      logger.debug 'server' do
        "%s:%d disconnected" % [
          addr.ip_address,
          addr.ip_port
        ]
      end
    end

    def rpc_ok(rpc, response, meta)
      logger.info rpc.name do
        "OK (%.2fms)" % [ meta.fetch(:latency) ]
      end
    end

    def rpc_error(rpc, ex, meta)
      logger.info rpc.name do
        "Error! %s (%.2fms)" % [
          ex.class.name,
          meta.fetch(:latency)
        ]
      end

      logger.error ex
    end

    def rpc_exception(rpc, ex, meta)
      logger.info rpc.name do
        "%s (%.2fms)" % [
          rpc.exception_name(ex),
          meta.fetch(:latency)
        ]
      end
    end
  end
end
