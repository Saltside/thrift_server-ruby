require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  attr_reader :service

  def setup
    @service = TestService
  end

  def wrap(service, &block)
    ThriftServer.wrap(service, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new,
    }, &block)
  end

  def test_wrap_fails_if_no_logger
    ex = assert_raises ArgumentError do
      ThriftServer.wrap(service, {
        statsd: FakeStatsd.new,
        error_tracker: NullErrorTracker.new,
      })
    end

    assert_match /logger/, ex.to_s
  end

  def test_wrap_fails_if_no_stats
    ex = assert_raises ArgumentError do
      ThriftServer.wrap(service, {
        logger: NullLogger.new,
        error_tracker: NullErrorTracker.new,
      })
    end

    assert_match /statsd/, ex.to_s
  end

  def test_wrap_fails_if_no_error_tracker
    ex = assert_raises ArgumentError do
      ThriftServer.wrap(service, {
        logger: NullLogger.new,
        statsd: FakeStatsd.new
      })
    end

    assert_match /error_tracker/, ex.to_s
  end

  def test_wrap_accepts_processor_itself
    handler = stub
    handler.expects(:getItems).with(:request).returns(:response)

    stack = wrap(TestService::Processor).new(handler)

    assert_equal :response, stack.process_getItems(:request)
  end

  def test_wraps_methods_defined_by_the_protocol
    handler = stub
    handler.expects(:getItems).with(:request).returns(:response)

    stack = wrap(service).new(handler)

    assert_equal :response, stack.process_getItems(:request)
  end

  def test_can_add_new_middleware_after_wrapping
    handler = mock
    handler.expects(:getItems).with(:modified_args)

    stack = wrap(service).new(handler)

    test_middleware = Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        env.args = :modified_args
        @app.call env
      end
    end

    stack.use test_middleware

    stack.process_getItems :request
  end

  def test_correctly_detects_protocol_exceptions
    stack = wrap(service).new(stub)

    test_middleware = Class.new do
      def initialize(app)
        @app = app
      end

      def call(rpc)
        if rpc.exceptions[:getItems_test] == TestException
          :ok
        else
          :missing_exception
        end
      end
    end

    stack.use test_middleware

    assert_equal :ok, stack.process_getItems(:request)
  end

  def test_correctly_detects_protocol_exceptions_from_inherited_service_in_other_namespace
    stack = wrap(service).new(stub)

    test_middleware = Class.new do
      def initialize(app)
        @app = app
      end

      def call(rpc)
        if rpc.exceptions[:ping_test] == TestException
          :ok
        else
          :missing_exception
        end
      end
    end

    stack.use test_middleware

    assert_equal :ok, stack.process_ping(:request)
  end

  def test_cannot_add_middleware_to_stack_after_first_rpc
    handler = stub getItems: :response

    stack = wrap(service).new(handler)

    stack.process_getItems :request

    ex = assert_raises RuntimeError do
      stack.use ->(rpc) { rpc }
    end

    assert_match /frozen/, ex.to_s
  end

  def test_wrap_yields_the_middleware_stack
    handler = mock
    handler.expects(:getItems).with(:from_block)

    test_middleware = Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        env.args = :from_block
        @app.call env
      end
    end

    stack_processor = wrap service do |stack|
      stack.use test_middleware
    end
    stack = stack_processor.new(handler)

    stack.process_getItems :request
  end

  def test_build_returns_thread_pool_server
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    })

    assert_instance_of Thrift::ThreadPoolServer, server
  end

  def test_build_defaults_to_port_9090
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    })

    assert_equal 9090, server.port
  end

  def test_build_accepts_port_options
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new,
      port: 5000
    })

    assert_equal 5000, server.port
  end

  def test_build_defaults_to_4_threads
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    })

    assert_equal 4, server.threads
  end

  def test_build_accepts_threads_option
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new,
      threads: 8
    })

    assert_equal 8, server.threads
  end

  def test_builds_creates_server_with_framed_transport
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    })

    assert_instance_of Thrift::FramedTransportFactory, server.transport_factory
  end

  def test_build_uses_server_socket_transport
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    })

    assert_instance_of Thrift::ServerSocket, server.server_transport
  end

  def test_build_creates_server_with_binary_protocol
    handler = stub getItems: :response
    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    })

    assert_instance_of Thrift::BinaryProtocolFactory, server.protocol_factory
  end

  def test_build_accepts_a_block_to_customize_the_middleware_stack
    handler = stub getItems: :response
    block_yielded = false

    server = ThriftServer.build(service, handler, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new
    }) do |stack|
      block_yielded = true

      assert_instance_of ThriftServer::MiddlewareStack, stack
    end

    assert block_yielded, 'Block not used'
  end
end
