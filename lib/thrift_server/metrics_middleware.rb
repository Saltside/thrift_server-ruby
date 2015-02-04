class ThriftServer
  class MetricsMiddleware
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.time rpc.name do
        app.call rpc
      end

      statsd.increment rpc.name
    rescue => ex
      statsd.increment 'errors'
      raise ex
    end
  end
end
