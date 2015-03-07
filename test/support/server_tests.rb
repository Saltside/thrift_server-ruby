module ServerTests
  def test_defaults_to_port_9090
    server = build service, stub
    assert_equal 9090, server.port
  end

  def test_accepts_port_options
    server = build(service, stub, {
      port: 5000
    })

    assert_equal 5000, server.port
  end

  def test_creates_server_with_framed_transport
    server = build service, stub

    assert_instance_of Thrift::FramedTransportFactory, server.transport
  end

  def test_uses_server_socket_transport
    server = build service, stub

    assert_instance_of Thrift::ServerSocket, server.server_transport
  end

  def test_creates_server_with_binary_protocol
    server = build service, stub

    assert_instance_of Thrift::BinaryProtocolFactory, server.protocol
  end

  def test_subscribers_receive_server_start
    subscriber = mock
    subscriber.expects(:server_start)

    server = build(service, stub) do |server|
      server.subscribe subscriber
    end

    server.start dry_run: true
  end

  def test_shortcut_method_for_attaching_log_subscriber
    ThriftServer::LogSubscriber.expects(:new).with(:stdout).returns(:generic)

    server = build(service, stub) do |server|
      server.log :stdout
    end

    assert_includes server.publisher, :generic
  end

  def test_shortcut_method_for_attaching_metrics
    ThriftServer::ServerMetricsSubscriber.expects(:new).with(:statsd).returns(:server)
    ThriftServer::RpcMetricsSubscriber.expects(:new).with(:statsd).returns(:rpc)

    server = build(service, stub) do |server|
      server.metrics :statsd
    end

    assert_includes server.publisher, :server
    assert_includes server.publisher, :rpc
  end

  def test_attaching_subscribers_to_server
    server = build(service, stub) do |server|
      server.subscribe :tester
    end

    assert_includes server.publisher, :tester
  end

  def test_adding_middleware_to_server
    test_middleware = Class.new do
      include Concord.new(:app)

      def call(env)
        app.call env
      end
    end

    server = build(service, stub) do |server|
      server.use test_middleware
    end
  end
end
