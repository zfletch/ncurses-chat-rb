#!/usr/bin/env ruby

require 'socket'
require 'thread'
require 'optparse'

options = {
  :port => '9281',
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on('-p', '--port PORT', 'Port to connect to (defaults to 9281)') {|p| options[:port] = p}
  opts.on('--verbose', 'Print verbose output') {options[:verbose] = true}
  opts.on('--help', 'Show this message') { puts opts; exit }
  opts.parse!
end

# class representing each unique connection
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

clients = [] # list of currently connected cliens
lock = Mutex.new # global lock
password = false # chatroom password

# The basic architecture is that multiple clients connect
# to a single server instance. The server waits for clients
# to send it messages and then sends those messages to all
# the other connected clients. Clients can give the server
# special commands by sending messages of the form /something
# and the server gives special messages to the clients by
# sending messages of the form !something. For example,
# if a client sends the server the message /list, the server
# sends the client the message !users followed by a whitespace
# separated list of usernames in the room.
#
# Each server instance, or chatroom, keeps track of ops,
# (the first user to join, or anyone they /op). Ops have
# special powers and can set a password for the room or kick
# other clients from the room.

# currently supported special commands
help = "/help: lists commands
/list: lists the users in the room
/me phrase: says <username> phrase instead of <username>: phrase
/quit: exits
/roll [n] [m]: rolls [n=1] [m=6]-sided die
/private password: make room private with password
/public: make room public
/op username: make username op
/ops: list ops
/msg username message: sends a private message to username
/kick username: kick username from room"

# start up server
server = TCPServer.open(options[:port])
puts "Started server on port #{options[:port]}"

while true

  # start a new thread for each client that connects
	Thread.start(server.accept) do |client|
		p client.addr if options[:verbose]

    # get username
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

    # if the chatroom has a password, require that
		begin
			if password
				client.puts "Please enter password"
				while client.gets.chomp != password
					client.puts "Incorrect password, please try again"
				end
			end
		rescue
			puts "Client does not exist" if options[:verbose]
			break
		end

    # on client join
		name = ''
		me = nil
		lock.synchronize do
			begin
				client.puts "Welcome to the chat. Type '/help' for a list of commands"
			rescue
				puts "Client does not exist" if options[:verbose]
				break
			end
			clients.each do |c|
				begin
					client.puts "!join #{c.username}"
				rescue
					break
				end
			end
      # if the client is the first in the room, make client an op
			if clients.size == 0
				clients << (me = Client.new(name = temp_name,client,true))
				op = true
			else
				clients << (me = Client.new(name = temp_name,client))
			end
			puts "!join #{name}" if options[:verbose]
			clients.each do |c|
				begin
					c.client.puts "!join #{name}"
				rescue
					puts "Error, client #{c} does not exist" if options[:verbose]
				end
			end
		end

    # process the message from a client
    # usually 'username: message' is sent to all clients, however
    # if the message is one of the following, it's handled specially
    # if /quit, send '!quit client' to all connected clients
    # if /list, send '!users list of connected clients' to client
    # if /roll [num] [dice], send all clients random dice rolls
    #   for (dice || 6) (num || 1)-sided dice
    # if /private pass, make the room private with password pass (only an op can do this),
    #   send '!private password' to all clients
    # if /public, makes the room public (only an op can do this)
    #   send '!public' to all clients
    #   in the above two cases, the message '!nop' is sent to the client if the client is not an op
    # if /msg username message, send message to username and no other clients
    #   if the username is not in the chat, send '!dne username' back to the client
    #   private messages are sent to clients in the form '!msg from to message'
    # if /op username, make username an op, send '!dne username' is user isn't in the chat
    #   and send '!nop' if the client is not an op
    # if /kick username, kick username from the room, requires op and sends !dne and
    #   !nop like the above command; also sends '!booted' to the client that's kicked out
    # if /me message, send 'username message' to all clients instead of the usual
    #   'username: message'
		loop do
			begin
				msg = client.gets.chomp
			rescue
				lock.synchronize do
					clients.reject! {|n| n.client == client}
					puts "!quit #{name}" if options[:verbose]
					clients.each do |c|
						begin
							c.client.puts "!quit #{name}"
						rescue
							puts "Error, client #{c} does not exist" if options[:verbose]
						end
					end
					break
				end
			end
			if msg == '/quit'
				lock.synchronize do
					clients.reject! {|n| n.client == client}
					puts "!quit #{name}" if options[:verbose]
					clients.each do |c|
						begin
							c.client.puts "!quit #{name}"
						rescue
							puts "Error, client #{c} does not exist" if options[:verbose]
						end
					end
					break
				end
				break
			elsif msg == '/list'
				client.puts "!users " + clients.reduce(''){|m,n| m + n.username + ' '}.chomp(' ') rescue break
			elsif msg == '/help'
				client.puts help rescue break
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
					msg = "!roll #{name} rolls #{num} #{dice}-sided #{(num == 1) ? "die" : "dice"}: "
					msg += num.times.reduce('') {|m,n| m + "#{rand(dice) + 1} "}.chomp(' ')
				elsif /^\/private / === msg
					if me.op
						passwd = msg.split(/\s/,2)[1]
						if /^\w{1,8}$/ === passwd
							password = passwd
							msg = "!private #{password}"
						else
							client.puts "!error password must be less than or equal to 8 alphanumeric characters" rescue break
							next
						end
					else
						client.puts "!nop" rescue break
						next
					end
				elsif msg == '/public'
					if me.op
						password = nil
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
						puts "!msg #{name} #{recv_client.username} #{rmsg}" if options[:verbose]
					else
						client.puts "!dne #{recv}" rescue break
					end
					next
				elsif msg == '/ops'
					client.puts "!ops " + clients.reduce(''){|m,n| n.op ? (m + n.username + ' ') : m}.chomp(' ') rescue break
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
				puts msg if options[:verbose]
				lock.synchronize do
					del = []
					clients.each do |c|
						begin
							c.client.puts msg
						rescue
							puts "Error, client #{c} does not exist" if options[:verbose]
						end
					end
				end
			end
		end
		client.close
	end
end

