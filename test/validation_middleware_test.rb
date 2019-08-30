require_relative 'test_helper'

class ValidationMiddlewareTest < Minitest::Test
  class StructResponse
    include ::Thrift::Struct

    attr_reader :id

    def initialize(id)
      @id = id
    end

    def ==(other)
      id == other.id
    end
  end

  class UnionResponse
    include ::Thrift::Struct_Union

    attr_reader :id

    def initialize(id)
      @id = id
    end

    def ==(other)
      id == other.id
    end
  end

  attr_reader :rpc, :validator

  def setup
    @rpc = ThriftServer::RPC.new :foo, :bar
    @validator = mock
  end

  def test_validates_struct_responses
    response = StructResponse.new :struct
    Thrift::Validator.expects(:new).returns validator
    validator.expects(:validate).with(response)

    app = stub call: response

    middleware = ThriftServer::ValidationMiddleware.new app

    assert_equal response, middleware.call(rpc)
  end

  def test_validates_union_responses
    response = UnionResponse.new :union
    Thrift::Validator.expects(:new).returns validator
    validator.expects(:validate).with(response)

    app = stub call: response

    middleware = ThriftServer::ValidationMiddleware.new app

    assert_equal response, middleware.call(rpc)
  end

  def test_passes_on_non_structs
    app = stub call: :response
    validator.expects(:validate).never

    middleware = ThriftServer::ValidationMiddleware.new app

    assert_equal :response, middleware.call(rpc)
  end
end
