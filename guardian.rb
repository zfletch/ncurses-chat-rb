#!/usr/bin/env ruby
# Usage:
# make this guy an op and he will op anyone who gives him the passwd

require 'socket'
require 'optparse'

options = {
  :hostname => 'localhost',
  :port => '9281',
  :nick => 'GUARDIAN',
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on('-h', '--hostname HOSTNAME', 'Hostname to connect to (defaults to localhost)') {|h| options[:hostname] = h}
  opts.on('-p', '--port PORT', 'Port to connect to (defaults to 9281)') {|p| options[:port] = p}
  opts.on('-n', '--nick NICK', 'Nick name to use (defaults to GUARDIAN)') {|n| options[:nick] = n}
  opts.on('--passwd PASSWORD', 'Password to make guardian opp you') {|p| options[:passwd] = p}
  opts.on('--help', 'Show this message') { puts opts; exit }
  opts.parse!
end

if !options[:passwd]
  puts "Enter password to op a user of the room"
  passwd = STDIN.gets.chomp
end

server = TCPSocket.open(options[:hostname], options[:port])

server.puts options[:nick]

loop do
	inp = server.gets.chomp
	inp = inp.split(/\s/, 4)
	if inp[0] == '!msg'
		if inp[3] == passwd
			server.puts "/op #{inp[1]}"
			puts "Opping #{inp[1]}"
		end
	end
end
