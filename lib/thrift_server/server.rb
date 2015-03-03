module ThriftServer
  class Server < Thrift::ThreadPoolServer
    extend Forwardable

    def_delegators :@processor, :use
    def_delegators :@processor, :publisher, :publish, :subscribe

    attr_accessor :port

    def log(logger)
      subscribe LogSubscriber.new(logger)
    end

    def metrics(statsd)
      subscribe ServerMetricsSubscriber.new(statsd)
      subscribe RpcMetricsSubscriber.new(statsd)
    end

    def threads
      @thread_q.max
    end

    def protocol
      @protocol_factory
    end

    def transport
      @transport_factory
    end

    def server_transport
      @server_transport
    end

    def start(dry_run: false)
      publish :server_start, self

      serve unless dry_run
    end

    # NOTE: this a direct copy of the upstream code with instrumentation added.
    def serve
      @server_transport.listen

      begin
        loop do
          @thread_q.push(:token)
          publish :server_thread_pool_change, delta: 1

          Thread.new do
            begin
              loop do
                client = @server_transport.accept
                remote_address = client.handle.remote_address

                publish :server_connection_opened, remote_address

                trans = @transport_factory.get_transport(client)
                prot = @protocol_factory.get_protocol(trans)
                begin
                  loop do
                    @processor.process(prot, prot)
                  end
                rescue Thrift::TransportException, Thrift::ProtocolException => e
                  publish :server_connection_closed, remote_address
                ensure
                  trans.close
                end
              end
            rescue => e
              @exception_q.push(e)
            ensure
              publish :server_thread_pool_change, delta: -1
              @thread_q.pop # thread died!
            end
          end
        end
      ensure
        @server_transport.close
      end
    end
  end
end
