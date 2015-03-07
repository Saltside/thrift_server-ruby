# ThriftServer

Encapsulate bolierplate code and functionality for running Thrift
servers in Ruby. Bundled functionality:

* Metrics for server & RPCs
* Logging for server events & RPCs
* Middleware & pub-sub based approach making it easy to extend
* Deep validation on outgoing protocol messages
* `Thrift::ThreadPoolServer` & `Thrift::ThreadedServer` support

## Installation

Add this line to your application's Gemfile:

    gem 'thrift_server'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install thrift_server

## Usage

The library uses delegation to around a provided handler & Thrift
processor to implement use production server behavior. There are two
different ways to extend function: pub sub & middleware. Use pub sub
for events & middleware when you want to modify the request & response
before/after hitting the handler. Out of the box there is not extra
behavior. Here's the bare bones useful server.

	server = ThriftServer.threaded EchoService, Handler.new

	server.log Logger.new($stdout)

	server.start

The first arument is a module containing a generated
`Thrift::Processor` subclass or the module itself. `ThriftServer`
provides factories for building `Thrift::ThreadedServer` and
`Thrift::ThreadPoolServer` instances.

### Threaded Servers

	server = ThriftServer.threaded EchoService, Handler.new

	server.log Logger.new($stdout)

	server.start

`ThriftServer.threaded` accepts the following options:

* `port:` - port to run server on. Defaults to `9090`.

### Thread Pool Servers

	server = ThriftServer.thread_pool EchoService, Handler.new

	server.log Logger.new($stdout)

	server.start

`ThriftServer.threaded` accepts the following options:

* `threads:` - Pool size. Defaults to `25`.
* `port:` - port to run server on. Defaults to `9090`.

## Pub Sub

Subscriber objects may be attached. The following events are
published:

* `rpc_incoming` - published everytime the server receives an RPC
* `rpc_ok` - Everything when according to plan
* `rpc_exception` - Handler raised an exception defined in the
  protocol
* `rpc_error` - Handler raised an unexpected error (useful for error
  tracking)
* `server_start` - Start started
* `server_connection_opened` - Client TCP connection
* `server_connection_closed` - Client TCP disconnect
* `thread_pool_server_pool_change` - Thread pool grow/shinks

The listener should implement a method. A listener will only receive
notifications if the appropriate method is implemented. Here's an
example:

	class Counter
		def initialize
			@counter = 0
		end

		def rpc_incoming(rpc)
			@counter += 1
		end
	end

	server = ThriftServer.threaded EchoService, Handler.new
	server.subscribe Counter.new

### Built-in Subscribers

`ThriftServer` includes three subscribers: two for metrics and one for
logging. The `ThriftServer::LogSubscriber` uses a standard library
logger to print useful information when any of the previously
mentioned events happen. Attaching the subscriber is so important that
it has its own helper method.

	server.log Logger.new($stdout)
	# Same thing as above, just much longer
	server.subscribe ThriftServer::LogSubscriber.new(Logger.new($stdout))

The remaining two middlware handle metrics. Each handles a different
metric granularity. `ThriftServer::ServerMetricsSubcriber` does stats
for all RPCs & server things. `ThriftServer::RpcMetricsSubscriber`
gives metrics for each individual RPC. Naturally there are important
subscribers and its highly recommend you add them. There is a shortcut
method for adding them both. They require a [statsd][] instance. You
can customize statsd prefix & postfix on that instance.

	server.metrics Statsd.new
	# Same thing as above, just much longer
	server.subscribe ThriftServer::ServerMetricsSubscriber.new(Statsd.new)
	server.subscribe ThriftServer::RpcMetricsSubscriber.new(Statsd.new)

`ThriftServer::ServerMetricsSubscriber` instruments the following
keys:

* `rpc.latency` - (timer)
* `rpc.incoming` - (counter)
* `rpc.success` - (counter) - Everything A-OK!
* `rpc.exception` - (counter) - Result was defined protocol exception
* `rpc.error` - (counter) - Uncaught errors
* `server.pool.size` - (guage) - Number of available threads
* `server.connection.active` - (guage) - Threads with active TCP connections

`ThriftServer::RpcMetricsSubscriber` produces the same metrics, but at
an individual RPC level. Assume the RPC is named `foo`.
keys:

* `rpc.foo.latency` (timer)
* `rpc.foo.incoming` (counter)
* `rpc.foo.success` (counter)
* `rpc.foo.exception` (counter)
* `rpc.foo.exception.xxx` (counter) - where `xxx` is listed in
  `throws` in the Thrift IDL.
* `rpc.foo.error` (counter)

## Middleware

The library uses a middleware approach to implement preprocessing of
each RPC before handing it off the original handler. You can
implement your own middleware easily. The middleware must respond to
`call` and accept a `ThriftServer::RPC` object.
`ThriftServer::RPC` is a simple struct with two members: `name` and
`args`. Here's an example that dumps the `args` to stdout.

    class ExampleMiddleware
		include Concord.new(:app)

		def call(rpc)
			puts rpc.args.inspect
			app.call rpc
		end
    end

New middleware can be added at build time or afterwards.

	ThriftServer.threaded processor, handler, options do |stack|
		stack.use ExampleMiddlware
	end

Middleware can also be added after the server is built

	server = ThriftServer.threaded processor, handler, options
	server.use ExampleMiddleware

	server.start # start it!

## Implementation

`ThriftServer` used metaprogramming and delegating to implement the
funcationality. `build` used the processor class to determine which
methods are required by the protocol. A middleware stack is created
using the object passed in the `options` hash. A delegate class is
created to wrap each method call to pass through the stack before
calling the defined handler. A subclass of the processor is defined to
wrap the handler provided in `initialize` in the delegate class.

## Development

	$ vagrant up
	$ vagrant ssh
	$ cd /vagrant
	$ make test-ci

## Contributing

1. Create your feature branch (`git checkout -b my-new-feature`)
2. Commit your changes (`git commit -am 'Add some feature'`)
3. Push to the branch (`git push origin my-new-feature`)
4. Create a new Pull Request

[statsd]: https://github.com/reinh/statsd
