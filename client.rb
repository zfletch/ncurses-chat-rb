#!/usr/bin/env ruby

if ARGV.size < 2
	puts "Usage: ruby client.rb hostname hostport [username]"
	exit
end

require 'socket'

hostname = ARGV[0]
port = ARGV[1].to_i

server = TCPSocket.open(hostname, port)

server.puts ARGV[2] if ARGV[2]

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
