require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  attr_reader :processor

  def setup
    @processor = Processor(:getItems)
  end

  def wrap(klass, &block)
    ThriftServer.wrap(processor, {
      logger: NullLogger.new,
      statsd: FakeStatsd.new,
      error_tracker: NullErrorTracker.new,
    }, &block)
  end

  def test_wrap_fails_if_no_logger
    ex = assert_raises ArgumentError do
      ThriftServer.wrap(processor, {
        statsd: FakeStatsd.new,
        error_tracker: NullErrorTracker.new,
      })
    end

    assert_match /logger/, ex.to_s
  end

  def test_wrap_fails_if_no_stats
    ex = assert_raises ArgumentError do
      ThriftServer.wrap(processor, {
        logger: NullLogger.new,
        error_tracker: NullErrorTracker.new,
      })
    end

    assert_match /statsd/, ex.to_s
  end

  def test_wrap_fails_if_no_error_tracker
    ex = assert_raises ArgumentError do
      ThriftServer.wrap(processor, {
        logger: NullLogger.new,
        statsd: FakeStatsd.new
      })
    end

    assert_match /error_tracker/, ex.to_s
  end

  def test_wraps_methods_defined_by_the_protocol
    handler = stub
    handler.expects(:getItems).with(:request).returns(:response)

    stack = wrap(processor).new(handler)

    assert_equal :response, stack.process_getItems(:request)
  end

  def test_can_add_new_middleware_after_wrapping
    handler = mock
    handler.expects(:getItems).with(:modified_args)

    stack = wrap(processor).new(handler)

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

  def test_cannot_add_middleware_to_stack_after_first_rpc
    handler = stub getItems: :response

    stack = wrap(processor).new(handler)

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

    stack_processor = wrap processor do |stack|
      stack.use test_middleware
    end
    stack = stack_processor.new(handler)

    stack.process_getItems :request
  end
end
