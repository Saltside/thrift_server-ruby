class ThriftServer
  class MetricsMiddleware
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.increment 'thrift.rpc.incoming'

      response = statsd.time 'thrift.rpc.latency' do
        app.call rpc
      end

      statsd.increment 'thrift.rpc.success'

      response
    rescue => ex
      statsd.increment 'thrift.rpc.error'
      raise ex
    end
  end
end
