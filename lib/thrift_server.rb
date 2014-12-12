require "thrift_server/version"

require 'middleware'
require 'concord'
require 'forwardable'

require_relative 'thrift_server/logging_middleware'
require_relative 'thrift_server/metrics_middleware'
require_relative 'thrift_server/error_tracking_middleware'
require_relative 'thrift_server/honeybadger_error_tracker'

class ThriftServer
  RPC = Struct.new(:name, :args)

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
    def wrap(processor, options = { })
      rpcs = processor.instance_methods.select { |m| m =~ /^process_(.+)$/ }

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
      stack.use MetricsMiddleware, statsd
      stack.use LoggingMiddleware, logger

      yield stack if block_given?

      wrapped = Class.new processor do
        extend Forwardable

        def_delegator :@handler, :use

        define_method :initialize do |handler|
          stack_delegator = Class.new StackDelegate
          stack_delegator.module_eval do
            rpcs.each do |method|
              rpc_name = method.to_s.match(/^process_(.+)$/)[1]

              define_method rpc_name.to_sym do |*args|
                call RPC.new(rpc_name, args)
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
