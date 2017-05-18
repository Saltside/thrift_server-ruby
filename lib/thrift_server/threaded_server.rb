module ThriftServer
  class ThreadedServer < Thrift::ThreadedServer
    class LogSubscriber
      include Concord.new(:logger)

      def server_start(server)
        logger.info :server do
          "Started on port %d" % [ server.port ]
        end

        logger.info :server do
          "-> Transport: %s" % [ server.transport ]
        end

        logger.info :server do
          "-> Protocol: %s" % [ server.protocol ]
        end
      end
    end

    extend Forwardable

    def_delegators :@processor, :use
    def_delegators :@processor, :publisher, :publish, :subscribe

    attr_accessor :port

    def log(logger)
      subscribe LogSubscriber.new(logger)
      subscribe ThriftServer::LogSubscriber.new(logger)
    end

    def metrics(statsd)
      subscribe ServerMetricsSubscriber.new(statsd)
      subscribe RpcMetricsSubscriber.new(statsd)
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

    # NOTE: this is a copy of the upstream code with instrumentation added.
    def serve
      begin
        @server_transport.listen
        loop do
          client = @server_transport.accept

          remote_address = client.handle.remote_address
          publish :server_connection_opened, remote_address

          trans = @transport_factory.get_transport(client)
          prot = @protocol_factory.get_protocol(trans)

          Thread.new(prot, trans) do |p, t|
            begin
              loop do
                @processor.process(p, p)
              end
            rescue Thrift::TransportException, Thrift::ProtocolException => ex
              publish :server_internal_error, remote_address, ex
            ensure
              publish :server_connection_closed, remote_address

              t.close
            end
          end
        end
      ensure
        @server_transport.close
      end
    end
  end
end
