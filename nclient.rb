#!/usr/bin/env ruby
# Ruby client using ncurses for the chat program
# To use: ruby nclient.rb hostname port [username]
# Should be used with corresponding server
# Zachary Fletcher

require 'ncurses'
require 'socket'

$disp = ['']*500
$start = 0
$connected = []

# Client side actions
# Make a copy and modify it to your liking
def interpret msg
	if /^!/ === msg
		msg2 = msg.split(/\s/,2)
		first = msg2[0]
		rest = msg2[1]
		case first
		when '!join'
			$connected << rest
			draw_room
			msg = "#{rest} has joined the room"
		when '!quit'
			$connected.delete rest
			draw_room
			msg = "#{rest} has left the room"
		when '!public'
			msg = "Room is now public"
		when '!private'
			msg = "Room is now private with password #{rest}"
		when '!msg'
			from,to,content = *rest.split(/\s/,3)
			msg = "#{from} says to #{to}: #{content}"
		when '!kick'
			msg = "#{rest} was kicked from the room"
		when '!booted'
			msg = "You have been kicked from the room"
		when '!op'
			msg = "#{rest} is now an op"
		when '!nop'
			msg = "You do not have permission to do that"
		when '!dne'
			msg = "user #{rest} does not exist"
		when '!ops'
			msg = "Ops: #{rest.split * ', '}"
		when '!users'
			msg = "Users: #{rest.split * ', '}"
    end
	end
	return msg
end

# draws the users in the room
def draw_room(start = 0)
	$three.clear
 	$three.border(*([0]*8))
	$three.wrefresh
	width = ($three.getmaxx-4)
	top = 1
	start.upto($three.getmaxy-4) do |i|
		$three.wmove(top,2)
		if $connected[i]
			$three.addstr($connected[i])
		else
			break
		end
		top += 1
	end
	$three.wrefresh
end

def read_line(y, x, window = Ncurses.stdscr, max_len = (window.getmaxx-x-1),string = "", cursor_pos = 0)
	window.clear
	window.border(*([0]*8))
	loop do
    window.mvaddstr(y,x,string)
    window.move(y,x+cursor_pos)
    ch = window.getch
    case ch
    when Ncurses::KEY_LEFT
      cursor_pos = [0, cursor_pos-1].max
    when Ncurses::KEY_RIGHT
      cursor_pos = [string.size,cursor_pos+1].min
    when Ncurses::KEY_ENTER, "\n".ord, "\r".ord
			cursor_pos = 0
			return string
    when Ncurses::KEY_BACKSPACE, 127
      string = string[0...([0, cursor_pos-1].max)] + string[cursor_pos..-1]
      cursor_pos = [0, cursor_pos-1].max
      window.mvaddstr(y, x+string.length, " ")
    when Ncurses::KEY_DC
      string = cursor_pos == string.size ? string : string[0...([0, cursor_pos].max)] + string[(cursor_pos+1)..-1]
      window.mvaddstr(y, x+string.length, " ")
    when 0..255 # remaining printables
      if string.size < (max_len - 1)
        string[cursor_pos,0] = ch.chr
        cursor_pos += 1
			end
		when Ncurses::KEY_UP
			# needs to be implemented, moves the screen up
    else
      #Ncurses.beep
    end
  end
end

# writes $disp[$start] to $disp[max] basically
def write_all(window, max, bottom, start = $start)
  width = (window.getmaxx-4 )
	i = start
	carry = 0
	carry_print = []
	max.times do
		if $disp[i].size > width
			carry_print << ($disp[i][(carry...(carry+width))])
			if ($disp[i].size - carry) > width
				carry = carry+width
				next
			else
				carry_print.reverse.each do |p|
					window.wmove(bottom,2)
					window.addstr p
					bottom -= 1
				end
				i = (i == $disp.size - 1) ? 0 : i + 1
				carry = 0
				carry_print = []
				next
			end
		end
		window.wmove(bottom,2)
		window.addstr($disp[i])
		i = (i == $disp.size - 1) ? 0 : i + 1
		bottom -= 1
	end
	carry_print.reverse.each do |p|
		window.move(bottom,2)
		window.addstr p
		bottom -= 1
	end
end

def draw_windows()

	one = Ncurses::WINDOW.new(Ncurses.LINES-3,Ncurses.COLS-12,0,0)
	two = Ncurses::WINDOW.new(3,0,Ncurses.LINES-3,0)
	$three = Ncurses::WINDOW.new(Ncurses.LINES-3,0,0,Ncurses.COLS-12)

	one.border(*([0]*8))
  two.border(*([0]*8))
  $three.border(*([0]*8))
	Ncurses.leaveok(one,true)
	one.nodelay(true)
	two.nodelay(true)
  two.move(1,2)
	$three.wrefresh

	Thread.new do
		loop do
			write_all(one,Ncurses.LINES-5,Ncurses.LINES-5)
			two.move(1,2)
  		one.border(*([0]*8))
			one.wrefresh
			one.clear
			msg = $server.gets.chomp
			$start = ($start == 0) ? ($disp.size-1) : $start - 1
			$disp[$start] = interpret(msg)
		end
	end

  two.keypad(true)
	loop do
		inp = read_line(1,2,two)
		$server.puts inp
		exit if inp == '/quit'
	end
end

begin

	if ARGV.size < 2
		puts "Usage: ruby client.rb hostname hostport [username]"
		exit
	end

  # initialize ncurses
  Ncurses.initscr
  Ncurses.cbreak
  Ncurses.noecho

	$hostname = ARGV[0]
	$port = ARGV[1].to_i

	$server = TCPSocket.open($hostname, $port)
	$server.puts ARGV[2] if ARGV[2]
	$server.puts ARGV[3] if ARGV[3]
	draw_windows()

ensure
  Ncurses.endwin rescue ''
end

