class ThriftServer
  class LoggingMiddleware
    include Concord.new(:app, :logger)

    def call(rpc)
      logger.info "Incoming RPC: #{rpc.name}"
      app.call rpc
    rescue => ex
      logger.error ex
      raise ex
    end
  end
end
