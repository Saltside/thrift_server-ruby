require "thrift_server/version"

require 'thrift'
require 'middleware'
require 'concord'
require 'forwardable'
require 'honeybadger'
require 'statsd-ruby'

require_relative 'thrift_server/logging_middleware'
require_relative 'thrift_server/server_metrics_middleware'
require_relative 'thrift_server/rpc_metrics_middleware'
require_relative 'thrift_server/error_tracking_middleware'
require_relative 'thrift_server/honeybadger_error_tracker'

class ThriftServer
  RPC = Struct.new(:name, :args, :exceptions) do
    def initialize(*)
      super
      self.exceptions ||= [ ]
    end

    def protocol_exception?(ex)
      exceptions.include? ex.class
    end
  end

  class MiddlewareStack < Middleware::Builder
    def finalize!
      stack.freeze
      to_app
    end
  end

  class StackDelegate
    class Dispatcher
      include Concord.new(:app, :handler)

      def call(rpc)
        handler.send rpc.name, *rpc.args
      end
    end

    extend Forwardable

    include Concord.new(:stack, :handler)

    def_delegator :stack, :use

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
    def build(processor, handler, options = { }, &block)
      stack = wrap(processor, options, &block).new handler
      transport = Thrift::ServerSocket.new options.fetch(:port, 9090)
      transport_factory = Thrift::FramedTransportFactory.new

      Thrift::ThreadPoolServer.new stack, transport, transport_factory, nil, options.fetch(:threads, 4)
    end

    def wrap(service_namespace, options = { })
      processor = service_namespace.const_get :Processor

      rpcs = processor.instance_methods.select { |m| m =~ /^process_(.+)$/ }
      rpc_names = rpcs.map { |m| m.to_s.match(/^process_(.+)$/)[1].to_sym }

      protocol_exceptions = rpc_names.each_with_object({ }) do |rpc_name, bucket|
        result_class = rpc_name.to_s
        result_class[0] = result_class[0].upcase

        fields = service_namespace.const_get("#{result_class}_result".to_sym).const_get(:FIELDS)

        exception_results = fields.values.select do |meta|
          meta.key?(:class) && meta.fetch(:class) < ::Thrift::Exception
        end

        bucket[rpc_name] = exception_results.map do |meta|
          meta.fetch :class
        end
      end

      logger = options.fetch :logger do
        fail ArgumentError, ':logger required'
      end

      statsd = options.fetch :statsd do
        fail ArgumentError, ':statsd required'
      end

      error_tracker = options.fetch :error_tracker do
        fail ArgumentError, ':error_tracker required'
      end

      stack = MiddlewareStack.new
      stack.use ErrorTrackingMiddleware, error_tracker
      stack.use ServerMetricsMiddleware, statsd
      stack.use RpcMetricsMiddleware, statsd
      stack.use LoggingMiddleware, logger

      yield stack if block_given?

      wrapped = Class.new processor do
        extend Forwardable

        def_delegator :@handler, :use

        define_method :initialize do |handler|
          stack_delegator = Class.new StackDelegate
          stack_delegator.module_eval do
            rpc_names.each do |rpc_name|
              define_method rpc_name do |*args|
                call RPC.new(rpc_name, args, protocol_exceptions.fetch(rpc_name, [ ]))
              end
            end
          end

          super stack_delegator.new(stack, handler)
        end
      end

      wrapped
    end
  end
end
