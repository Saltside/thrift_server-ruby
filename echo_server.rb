$stdout.sync = true
$stderr.sync = true

require 'bundler/setup'
require 'thrift_server'

$LOAD_PATH << "#{__dir__}/gen-rb"

require 'echo_service'

class Handler
  def echo(msg)
    msg
  end
end

class ErrorTracker
  def track(*)

  end
end

logger = Logger.new $stdout

server = ThriftServer.build(EchoService::Processor, Handler.new, {
  logger: logger,
  statsd: Statsd.new,
  error_tracker: ErrorTracker.new
})

logger.info 'Starting server'

server.serve
