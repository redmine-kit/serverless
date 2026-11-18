# frozen_string_literal: true

# Forwards 127.0.0.1:<port> to <host>:<port>, for the tests in Apple container
# (bin/test-image): AWS Emulator's certificate names only 127.0.0.1 and localhost,
# and Apple container can't run a container in another one's network
# namespace, as Docker does. bin/test-image starts it in each container, in
# the background, before its command:
#   ruby /test/aws_forward.rb <emulator address> 9297
require 'socket'

host, port = ARGV
server = TCPServer.new('127.0.0.1', Integer(port))

# Copies one direction of a connection until it ends.
def pipe(from, to)
  IO.copy_stream(from, to)
rescue IOError, SystemCallError
  nil
ensure
  begin
    to.close_write
  rescue IOError, SystemCallError
    nil
  end
end

loop do
  Thread.new(server.accept) do |client|
    upstream = TCPSocket.new(host, Integer(port))
    [Thread.new { pipe(client, upstream) }, Thread.new { pipe(upstream, client) }].each(&:join)
  rescue IOError, SystemCallError
    nil
  ensure
    client.close
    upstream&.close
  end
end
