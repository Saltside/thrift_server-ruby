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

if ARGV.include?('--threaded')
  server = ThriftServer.threaded EchoService, Handler.new
  server.log Logger.new($stdout)
  server.start
elsif ARGV.include?('--thread-pool')
  server = ThriftServer.thread_pool EchoService, Handler.new
  server.log Logger.new($stdout)
  server.start
else
  abort 'No server option given'
end
