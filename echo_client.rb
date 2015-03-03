$stdout.sync = true
$stderr.sync = true

require 'bundler/setup'
require 'thrift_server'

$LOAD_PATH << "#{__dir__}/gen-rb"

require 'echo_service'

host, port = ARGV[0], ARGV[1]

if !host || !port
  $stdout.puts "usage: echo_client HOST PORT"
  abort
end

logger = Logger.new $stdout

transport = Thrift::FramedTransport.new(Thrift::Socket.new(host, port.to_i))
transport.open

protocol = Thrift::BinaryProtocol.new transport
client = EchoService::Client.new protocol

response = client.echo "testing"

if response == 'testing'
  $stdout.puts 'OK'
else
  $stderr.puts 'Message not echoed'
  abort
end

response = client.structEcho 'testing'

if response.message == 'testing'
  $stdout.puts 'OK'
else
  $stderr.puts 'Message not echoed'
  abort
end

begin
  client.structEcho 'exception'
rescue EchoException
  $stdout.puts 'OK'
else
  abort 'Protocol exception lost'
end

client.ping 'hello'

transport.close
