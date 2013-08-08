#!/usr/bin/env ruby

require 'socket'
require 'thread'

class Client
	def initialize(username, client, op=false)
		@username = username
		@start = Time.new
		@client = client
		@op = op
	end
	attr_reader :username, :client
	attr_accessor :op
	def time() Time.new - start	end
	def to_s() @username end
end
clients = []
lock = Mutex.new

$passwd = false
$help = "/help : lists commands
/list : lists the users in the room
/me phrase : says <username> phrase instead of <username>: phrase
/quit : exits
/roll [n] [m] : rolls [n=1] [m=6]-sided die
/private password : make room private with password
/public : make room public
/op username : make username op
/ops : list ops
/msg username message : sends a private message to username
/kick username : kick username from room"

if ARGV.size != 1
  puts "Usage: ruby server.rb port"
  exit
end

server = TCPServer.open(ARGV[0].to_i)
while true
	Thread.start(server.accept) do |client|
		p client.addr
		client.puts "Welcome to the server" rescue break
		client.puts "Enter a username" rescue break
		temp_name = ''
		loop do
			begin
				temp_name = client.gets.chomp
				if clients.reduce(false) {|m,n| n.username == temp_name ? true : m}
					client.puts "That name is already in use, enter another one" rescue break
					next
				elsif !(/^\w{1,8}$/ === temp_name)
					client.puts "Name must be from 1-8 alphanumeric characters"
					next
				else
					break
				end
			rescue
				break
			end
		end
		begin
			if $passwd
				client.puts "Please enter password"
				while client.gets.chomp != $passwd
					client.puts "Incorrect password, please try again"
				end
			end
		rescue
			puts "Client does not exist"
			break
		end
		name = '' # fuck scopes
		me = nil
		lock.synchronize do
			begin
				client.puts "Welcome to the chat. Type '/help' for a list of commands"
			rescue
				puts "Client does not exist"
				break
			end
			clients.each do |c|
				begin
					client.puts "!join #{c.username}"
				rescue
					break
				end
			end
			if clients.size == 0
				clients << (me = Client.new(name = temp_name,client,true))
				op = true
			else
				clients << (me = Client.new(name = temp_name,client))
			end
			puts "!join #{name}"
			clients.each do |c|
				begin
					c.client.puts "!join #{name}"
				rescue
					p c
					puts "Error, client #{c} does not exist"
				end
			end

		end
		loop do
			begin
				msg = client.gets.chomp
			rescue
				lock.synchronize do
					clients.reject! {|n| n.client == client}
					puts "!quit #{name}"
					clients.each do |c|
						begin
							c.client.puts "!quit #{name}"
						rescue
							puts "Error, client #{c} does not exist"
						end
					end
					break
				end
			end
			if msg == '/quit'
				lock.synchronize do
					clients.reject! {|n| n.client == client}
					#clients = clients.find_all {|c| c.username != name}
					puts "!quit #{name}"
					clients.each do |c|
						begin
							c.client.puts "!quit #{name}"
						rescue
							puts "Error, client #{c} does not exist"
						end
					end
					break
				end
				break
			elsif msg == '/list'
				client.puts "!users "+clients.reduce(''){|m,n| m + n.username + ' '}.chomp(' ') rescue break
			elsif msg == '/help'
				client.puts $help rescue break
			else
				if /^\/roll / === msg or msg == '/roll'
					spl = msg.split
					num = 1
					dice = 6
					if spl.size >= 2
						num = spl[1].to_i
						num = (num > 10) ? 10 : num
						num = (num < 1) ? 1 : num
					end
					if spl.size >= 3
						dice = spl[2].to_i
						dice = (dice > 99) ? 99 : dice
						dice = (dice < 1) ? 1 : dice
					end
					msg = "!#{name} rolls #{num} #{dice}-sided #{(num == 1) ? "die" : "dice"}: "
					msg += num.times.reduce('') {|m,n| m + "#{rand(dice) + 1} "}.chomp(' ')
				elsif /^\/private / === msg
					if me.op
						passwd = msg.split(/\s/,2)[1]
						if /^\w{1,8}$/ === passwd
							$passwd = passwd
							msg = "!private #{$passwd}"
						else
							client.puts "!input_error 8 alphanumeric" rescue break
							next
						end
					else
						client.puts "!nop" rescue break
						next
					end
				elsif msg == '/public'
					if me.op
						$passwd = nil
						msg = "!public"
					else
						client.puts "!nop" rescue break
						next
					end
				elsif /^\/msg / === msg
					msplit = msg.split(/\s/,3)
					recv = msplit[1]
					rmsg = msplit[2]
					recv_client = clients.find {|c| c.username == recv}
					if recv_client
						recv_client.client.puts "!msg #{name} #{recv_client.username} #{rmsg}" rescue next
						client.puts "!msg #{name} #{recv_client.username} #{rmsg}" rescue break
						puts "!msg #{name} #{recv_client.username} #{rmsg}"
					else
						client.puts "!dne #{recv}" rescue break
					end
					next
				elsif msg == '/ops'
					client.puts "!ops "+clients.reduce(''){|m,n| n.op ? (m + n.username + ' ') : m}.chomp(' ') rescue break
					next
				elsif /^\/op / === msg
					new_op_name = msg.split(/\s/,2)[1]
					if me.op
						new_op = clients.find {|c| c.username == new_op_name}
						if new_op
							lock.synchronize {new_op.op = true}
							msg = "!op #{new_op_name}"
						else
							client.puts "!dne #{new_op_name}" rescue break
							next
						end
					else
						client.puts "!nop" rescue break
						next
					end
				elsif /^\/kick / === msg
					if me.op
						kicked = msg.split(/\s/,2)[1]
						kicked_client = clients.find {|n| n.username == kicked}
						if kicked_client
							if kicked_client.op
								client.puts "!nop" rescue break
								next
							end
							lock.synchronize do
								clients.reject! {|n| n.username == kicked}
								kicked_client.client.puts "!booted" rescue ''
								kicked_client.client.close
							end
							msg = "!kick #{kicked}"
						else
							client.puts "!dne #{kicked}" rescue break
							next
						end
					else
						client.puts "!nop" rescue break
						next
					end
				elsif /^\/me / === msg
					msg.sub!("/me",name)
				elsif msg[0] != '/'[0] and msg[0] != '!'[0]
					msg = "#{name}: #{msg}"
				else
					next
				end
				puts msg
				lock.synchronize do
					del = []
					clients.each do |c|
						begin
							c.client.puts msg
						rescue
							puts "Error, client #{c} does not exist"
						end
					end
				end
			end
		end
		client.close
	end
end
