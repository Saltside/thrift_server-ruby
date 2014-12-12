class ThriftServer
  class ErrorTrackingMiddleware
    include Concord.new(:app, :logger)

    def call(rpc)
      app.call rpc
    rescue => ex
      logger.track rpc, ex
      raise ex
    end
  end
end
