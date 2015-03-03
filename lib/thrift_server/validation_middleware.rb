module ThriftServer
  class ValidationMiddleware
    include Concord.new(:app)

    def call(rpc)
      app.call(rpc).tap do |response|
        case response
        when Thrift::Struct, Thrift::Struct_Union
          Thrift::Validator.new.validate response
        end
      end
    end
  end
end
