require "thrift_server/version"

require 'thrift'
require 'thrift-validator'
require 'middleware'
require 'concord'
require 'forwardable'
require 'statsd-ruby'

require_relative 'thrift_server/instrumentation_middleware'
require_relative 'thrift_server/validation_middleware'

require_relative 'thrift_server/server_metrics_subscriber'
require_relative 'thrift_server/rpc_metrics_subscriber'
require_relative 'thrift_server/log_subscriber'

require_relative 'thrift_server/publisher'

require_relative 'thrift_server/thread_pool_server'
require_relative 'thrift_server/threaded_server'

module ThriftServer
  RPC = Struct.new(:name, :args, :exceptions) do
    def initialize(*)
      super
      self.exceptions ||= { }
    end

    def protocol_exception?(ex)
      exceptions.values.include? ex.class
    end

    def exception_name(ex)
      exceptions.invert.fetch ex.class
    end

    def to_s
      name.to_s
    end
  end

  class MiddlewareStack < Middleware::Builder
    def finalize!
      stack.freeze
      to_app
    end
  end

  class HandlerWrapper
    class Dispatcher
      include Concord.new(:app, :handler)

      def call(rpc)
        handler.send rpc.name, *rpc.args
      end
    end

    extend Forwardable

    include Concord::Public.new(:stack, :publisher, :handler)

    attr_reader :publisher, :handler, :stack

    def call(rpc)
      app.call rpc
    end

    private

    def app
      @app ||= finalize_stack!
    end

    def finalize_stack!
      stack.use Dispatcher, handler
      stack.finalize!
    end
  end

  class << self
    def thread_pool(root, handler, options = { })
      stack = wrap(root, options).new handler

      threads, port = options.fetch(:threads, 25), options.fetch(:port, 9090)

      transport = Thrift::ServerSocket.new port
      transport_factory = Thrift::FramedTransportFactory.new

      ThreadPoolServer.new(stack, transport, transport_factory, nil, threads).tap do |server|
        # Assign bookkeeping data that is spread across multiple objects
        server.port = port

        yield server if block_given?
      end
    end

    def threaded(root, handler, options = { })
      stack = wrap(root, options).new handler

      port = options.fetch :port, 9090

      transport = Thrift::ServerSocket.new port
      transport_factory = Thrift::FramedTransportFactory.new

      ThreadedServer.new(stack, transport, transport_factory).tap do |server|
        # Assign bookkeeping data that is spread across multiple objects
        server.port = port

        yield server if block_given?
      end
    end

    def wrap(root, options = { })
      processor = root < ::Thrift::Processor ? root : root.const_get(:Processor)

      processors = processor.ancestors.select do |ancestor|
        ancestor < ::Thrift::Processor
      end

      processor_rpcs = processors.each_with_object({ }) do |ancestor, bucket|
        rpc_methods = ancestor.
          instance_methods(include_superclass = false).
          select { |m| m =~ /^process_(.+)$/ }

        rpc_names = rpc_methods.map do |rpc_method|
          rpc_method.to_s.match(/^process_(.+)$/)[1]
        end

        bucket[ancestor] = rpc_names.map(&:to_sym)
      end

      rpc_names = processor_rpcs.flat_map do |_, values|
        values
      end

      rpc_protocol_exceptions = processor_rpcs.each_with_object({ }) do |(processor_klass, rpcs), bucket|
        rpcs.each do |rpc|
          result_class = rpc.to_s
          result_class[0] = result_class[0].upcase
          result_class_name = "#{result_class}_result"

          service_namespace = processor_klass.name.match(/^(.+)::Processor$/)[1]

          fields = Object.const_get "#{service_namespace}::#{result_class_name}::FIELDS"

          exception_fields = fields.values.select do |meta|
            meta.key?(:class) && meta.fetch(:class) < ::Thrift::Exception
          end

          bucket[rpc] = exception_fields.each_with_object({ }) do |meta, exceptions|
            exceptions[meta.fetch(:name).to_sym] = meta.fetch(:class)
          end
        end
      end

      publisher = Publisher.new

      stack = MiddlewareStack.new
      stack.use InstrumentationMiddleware, publisher
      stack.use ValidationMiddleware

      wrapped = Class.new processor do
        extend Forwardable

        def_delegators :@handler, :stack
        def_delegators :@handler, :publisher

        def_delegators :stack, :use
        def_delegators :publisher, :publish, :subscribe

        define_method :initialize do |handler|
          stack_delegator = Class.new HandlerWrapper
          stack_delegator.module_eval do
            rpc_names.each do |rpc_name|
              define_method rpc_name do |*args|
                call RPC.new(rpc_name, args, rpc_protocol_exceptions.fetch(rpc_name, [ ]))
              end
            end
          end

          super stack_delegator.new(stack, publisher, handler)
        end
      end

      wrapped
    end
  end
end
