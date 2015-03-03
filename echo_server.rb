$stdout.sync = true
$stderr.sync = true

require 'bundler/setup'
require 'thrift_server'

$LOAD_PATH << "#{__dir__}/gen-rb"

require 'echo_service'

class Handler
  def echo(message)
    message
  end

  def structEcho(message)
    case message
    when /exception/
      fail EchoException
    else
      EchoResponse.new message: message
    end
  end

  def ping(message)
    # async, into the ether!
  end
end

class ErrorTracker
  def track(*)

  end
end

logger = Logger.new $stdout

server = ThriftServer.build(EchoService, Handler.new, {
  logger: logger,
  statsd: Statsd.new,
  error_tracker: ErrorTracker.new
})

logger.info 'Starting server'

server.serve
