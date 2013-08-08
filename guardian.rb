#!/usr/bin/env ruby
# Usage:
# ruby guardian.rb hostname port [room passwd]
# make this guy an op and he will op anyone who gives him the passwd

if ARGV.size < 2 or ARGV.size > 3
	puts "Usage: ruby guardian.rb hostname port [room passwd]"
	exit
end

require 'socket'

puts "Enter password to op a user of the room"
$passwd = STDIN.gets.chomp

$hostname, $port = ARGV[0], ARGV[1]
$server = TCPSocket.open($hostname, $port)

if ARGV.size == 2
	$server.puts 'GUARDIAN'
elsif ARGV.size == 3
	$server.puts 'GUARDIAN'
	$server.puts ARGV[2]
end

loop do
	inp = $server.gets.chomp
	inp = inp.split(/\s/,4)
	if inp[0] == '!msg'
		if inp[3] == $passwd
			$server.puts "/op #{inp[1]}"
			puts "Opping #{inp[1]}"
		end
	end
end
