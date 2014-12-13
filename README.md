# ThriftServer

Encapsulate bolierplate code and functionality for running Thrift
servers in Ruby. Bundled functionality:

* Error tracking
* Metrics on each RPC
* Logging on each RPC
* Middleware based approaching making it easy to extend
* Binary protocol
* Framed transport
* Thread pool sever

## Installation

Add this line to your application's Gemfile:

    gem 'thrift_server'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install thrift_server

## Usage

The libary is defined to wrapping Thrift's processor classes in useful
functionality for production servers. You must provide objects
required to implement the behavior. Here's an example from
[echo\_server.rb](echo_server.rb).

    server = ThriftServer.build(EchoService::Processor, Handler.new, {
        logger: Logger.new($stdout),
        statsd: Statsd.new,
        error_tracker: ErrorTracker.new
    })

    # Now call serve to start it
    server.serve

The first arument is a generated `Thrift::Processor` subclass. The second
is your implementation of the define protocol. The options hash
defines all the misc objecs and settings. The following options are
available:

* `logger:` - a `Logger` instance
* `statsd:` - a `Statsd` instance from the [statsd-ruby gem](https://github.com/reinh/statsd)
* `error_tracker:` object that implement `#track(rpc, error). Use
  `ThriftServer::HoneybaderErrorTracker` if unsure
* `threads:` - number of threads to run. Defaults to `4`
* `port:` - port to run server on. Defaults to `9090`

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

    ThriftServer::build processor, handler, options do |stack|
        stack.use ExampleMiddlware
    end

Middleware can also be added after the server is built

    server = ThriftServer::build processor, handler, options
    server.use ExampleMiddleware
    serve.serve # start it!

## Implementation

`ThriftServer` used metaprogramming and delegating to implement the
funcationality. `build` used the processor class to determine which
methods are required by the protocol. A middleware stack is created
using the object passed in the `options` hash. A delegate class is
created to wrap each method call to pass through the stack before
calling the defined handler. A subclass of the processor is defined to
wrap the handler provided in `initialize` in the delegate class.

## Contributing

1. Create your feature branch (`git checkout -b my-new-feature`)
2. Commit your changes (`git commit -am 'Add some feature'`)
3. Push to the branch (`git push origin my-new-feature`)
4. Create a new Pull Request
