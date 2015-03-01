class ThriftServer
  class LoggingMiddleware
    include Concord.new(:app, :logger)

    def call(rpc)
      app.call(rpc).tap do
        logger.info "RPC: #{rpc.name} / OK"
      end
    rescue => ex
      if rpc.protocol_exception?(ex)
        logger.info "RPC: #{rpc.name} / exception: #{rpc.exception_name(ex)}"
      else
        logger.info "RPC: #{rpc.name} / error: #{ex.class.name}"
        logger.error ex
      end

      raise ex
    end
  end
end
