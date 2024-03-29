require_relative 'test_helper'

class ProcessorTest < Minitest::Test
  attr_reader :service

  def setup
    @service = TestService
  end

  def wrap(service, &block)
    ThriftServer.wrap service, &block
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

  def test_can_add_new_middleware_after_building
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

  def test_subscribers_receive_incoming_rpcs
    handler = stub
    handler.expects(:getItems).with(:request).returns(:response)

    subscriber = stub
    processor = wrap(service).new handler

    processor.subscribe subscriber

    subscriber.expects(:rpc_incoming).with do |request, meta|
      request.name == :getItems
    end

    processor.process_getItems(:request)
  end

  def test_subscribers_receive_successful_rpcs
    handler = stub
    handler.expects(:getItems).with(:request).returns(:response)

    subscriber = stub
    processor = wrap(service).new handler

    processor.subscribe subscriber

    subscriber.expects(:rpc_ok).with do |request, response, meta|
      request.name == :getItems &&
        response == :response &&
        meta.fetch(:latency).is_a?(Float)
    end

    processor.process_getItems(:request)
  end

  def test_subscribers_receive_rpc_errors
    error = StandardError.new

    handler = stub
    handler.expects(:getItems).with(:request).raises(error)

    subscriber = stub
    processor = wrap(service).new handler

    processor.subscribe subscriber

    subscriber.expects(:rpc_error).with do |request, ex, meta|
      request.name == :getItems &&
        ex == error &&
        meta.fetch(:latency).is_a?(Float)
    end

    assert_raises StandardError do
      processor.process_getItems :request
    end
  end

  def test_subscribers_receive_documented_rpc_protocol_exceptions
    error = TestException.new :placeholder

    handler = stub
    handler.expects(:getItems).with(:request).raises(error)

    subscriber = stub
    processor = wrap(service).new handler

    processor.subscribe subscriber

    subscriber.expects(:rpc_exception).with do |request, ex, meta|
      request.name == :getItems &&
        ex == error &&
        meta.fetch(:latency).is_a?(Float)
    end

    assert_raises TestException do
      processor.process_getItems :request
    end
  end
end
