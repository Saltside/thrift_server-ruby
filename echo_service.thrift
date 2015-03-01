exception EchoException { }

struct EchoResponse {
  1: required string message
}

service EchoService {
  string echo(1: string message)

  EchoResponse structEcho(1: string message)
    throws (1: EchoException echo)

  oneway void ping(1: string message)
}
