ncurses chat
============

Chat server and client using ncurses in ruby.

Description
-----------

Simple chat server, client, and ncurses client
written in ruby using the ruby-ncurses library.

The basic setup: starting a server creates a chat room
that clients can connect to.
The server and clients use TCP Sockets to communicate.
The clients can send commands to the server
to op other clients, private message other clients,
add a password to the room, and some other things
clients can usually do in group chat programs.

If someone out there is looking for some code examples
for using ncurses-ruby or for making a simple chat program,
I hope this code will come in handy.

How to use
----------

 - gem install ncurses-ruby
 - git clone https://github.com/zfletch/ncurses-chat-rb
 - cd ncurses-chat-rb
 - ruby server.rb
 - (in another terminal window) ruby nclient.rb
 - type '/help' in the client to see a list of commands

Examples
--------

Simple example of multiple users using the chat.
![simple](https://github.com/zfletch/ncurses-chat-rb/blob/master/pictures/simple.png?raw=true)

Slightly more complicated example using the guardian.rb script
to create a bot that sits in the room and ops people who
message it the password.
![guardian](https://github.com/zfletch/ncurses-chat-rb/blob/master/pictures/guardian.png?raw=true)

Notes
-----

Tested on ruby 2.0.0 on OSX 10.8.4.
