class ThriftServer
  class ErrorTrackingMiddleware
    include Concord.new(:app, :logger)

    def call(rpc)
      app.call rpc
    rescue => ex
      logger.track rpc, ex unless rpc.protocol_exception? ex
      raise ex
    end
  end
end
