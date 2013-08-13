#!/usr/bin/env ruby

require 'socket'
require 'optparse'

options = {
  :hostname => 'localhost',
  :port => '9281',
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on('-h', '--hostname HOSTNAME', 'Hostname to connect to (defaults to localhost)') {|h| options[:hostname] = h}
  opts.on('-p', '--port PORT', 'Port to connect to (defaults to 9281)') {|p| options[:port] = p}
  opts.on('-n', '--nick NICK', 'Nick name to use (if left blank, you can choose on login)') {|n| options[:nick] = n}
  opts.on('--help', 'Show this message') { puts opts; exit }
  opts.parse!
end

server = TCPSocket.open(options[:hostname], options[:port])

server.puts options[:nick] if options[:nick]

Thread.new do
	loop do
		puts server.gets.chomp
	end
end

loop do
	inp = STDIN.gets.chomp
	server.puts inp
	break if inp == '/exit'
end

server.close
