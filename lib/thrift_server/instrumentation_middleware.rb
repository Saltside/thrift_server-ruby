module ThriftServer
  class InstrumentationMiddleware
    extend Forwardable

    def_delegators :publisher, :publish

    include Concord.new(:app, :publisher)

    def call(rpc)
      start_time = Time.now

      publish :rpc_incoming, rpc

      app.call(rpc).tap do |response|
        latency = (Time.now - start_time) * 1000

        publish :rpc_ok, rpc, response, {
          latency: latency
        }
      end
    rescue => ex
      latency = (Time.now - start_time) * 1000

      if rpc.protocol_exception? ex
        publish :rpc_exception, rpc, ex, latency: latency
      else
        publish :rpc_error, rpc, ex, latency: latency
      end

      raise ex
    end
  end
end
