class ThriftServer
  class ServerMetricsMiddleware
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.increment 'rpc.incoming'

      response = statsd.time 'rpc.latency' do
        app.call rpc
      end

      statsd.increment 'rpc.success'

      response
    rescue => ex
      statsd.increment 'rpc.error'
      raise ex
    end
  end
end
