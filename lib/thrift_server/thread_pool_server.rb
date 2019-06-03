module ThriftServer
  class ThreadPoolServer < Thrift::ThreadPoolServer
    class LogSubscriber
      include Concord.new(:logger)

      def server_start(server)
        logger.info :server do
          "Started on port %d" % [ server.port ]
        end

        logger.info :server do
          "-> Threads: %d" % [ server.threads ]
        end

        logger.info :server do
          "-> Transport: %s" % [ server.transport ]
        end

        logger.info :server do
          "-> Protocol: %s" % [ server.protocol ]
        end
      end
    end

    class MetricsSubscriber
      include Concord.new(:statsd)

      def thread_pool_server_pool_change(meta)
        statsd.gauge('server.pool.size', '%+d' % [ meta.fetch(:delta) ])
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
      subscribe MetricsSubscriber.new(statsd)
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
          publish :thread_pool_server_pool_change, delta: 1

          Thread.new do
            begin
              loop do
                client = @server_transport.accept

                skip_publishing = false
                begin
                  remote_address = client.handle.remote_address
                  publish :server_connection_opened, remote_address
                rescue => ex
                  skip_publishing = true
                  logger.error ex
                end

                trans = @transport_factory.get_transport(client)
                prot = @protocol_factory.get_protocol(trans)
                begin
                  loop do
                    @processor.process(prot, prot)
                  end
                rescue Thrift::TransportException, Thrift::ProtocolException => e
                  publish(:server_connection_closed, remote_address) unless skip_publishing
                ensure
                  trans.close
                end
              end
            rescue => e
              @exception_q.push(e)
            ensure
              publish :thread_pool_server_pool_change, delta: -1
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
