#!/usr/bin/env ruby

require 'gserver'
require 'net/http'
require 'uri'

class GlobalChatServer < GServer
  
  attr_accessor :handles, :buffer, :handle_keys, :sockets, :password, :socket_keys
  
  def initialize(port=9994, *args)
    super(port, *args)
    self.audit = true
    self.debug = true
    @handle_keys = {}
    @socket_keys = {}
    @port_keys = {}
    @handles = []
    @sockets = []
    @buffer = []
    @mutex = Mutex.new
  end
  
  def broadcast(message, sender=nil)
    @mutex.synchronize do
      @sockets.each do |socket|
        begin
          #socket.send message unless socket == sender
          sock_send(socket, message) unless socket == sender
        rescue
          log "dead socket event"
          @sockets.delete socket
          ct = @socket_keys[socket]
          handle = @handle_keys[ct]
          @handles.delete handle
          @handle_keys.delete ct
          @socket_keys.delete socket
          # broadcast_message(socket, "LEAVE", [handle])
        end
      end
    end
  end
  
  def check_token(chat_token)
    sender = @handle_keys[chat_token]
    return !sender.nil?
  end
  
  def get_handle(chat_token)
    sender = @handle_keys[chat_token]
    return sender
  end
  
  # server tell a single socket
  def send_message(io, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send io, msg
  end
  
  def sock_send io, msg
    msg = "#{msg}\0"
    log msg
    io.send msg, 0
  end
  
  # server tell all sockets except
  # if sender is nil then everyone
  def broadcast_message(sender, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    broadcast msg, sender
  end
  
  
  # react to allowed commands
  def parse_line(line, io)
    parr = line.split("::!!::")
    command = parr[0]
    if command == "SIGNON"
      handle = parr[1]
      password = parr[2]

      if @handles.include?(handle)
        handle = "#{handle}#{rand(1000)}"
      end
      
      if (@password == password) || ((password === nil) && (@password == ""))
        
        chat_token = rand(36**8).to_s(36)
        @mutex.synchronize do
          @handle_keys[chat_token] = handle
          @socket_keys[io] = chat_token
          @port_keys[io.peeraddr[1]] = chat_token
          @handles << handle
          @sockets << io
        end
        send_message(io, "TOKEN", [chat_token])
        broadcast_message(io, "JOIN", [handle])
      end
      
      return
      
    end
    
    # auth
    chat_token = parr.last
      
    if check_token(chat_token)
      handle = get_handle(chat_token)
      if command == "GETHANDLES"
        @handles.each do |handle|
          send_message(io, "HANDLE", [handle])
        end
      elsif command == "GETBUFFER"
        @buffer.each do |msg|
          send_message(io, "SAY", [msg[0], msg[1]])
        end
      elsif command == "MESSAGE"
        msg = parr[1]
        message = "#{handle}: #{msg}\n"
        @buffer << [handle, msg]
        broadcast_message(io, "SAY", [handle, msg])
      elsif command == "SIGNOFF"
        @handles.delete handle
        @handle_keys.delete chat_token
        broadcast_message(io, "LEAVE", [handle])
      end
    end
  end
  
  def connecting(client)
    super(client)
  end
  def disconnecting(clientPort)
    log "disconnect event"
    ct = @port_keys[clientPort]
    handle = @handle_keys[ct]
    if handle
      socket = @socket_keys.key(ct)
      @handles.delete handle
      @handle_keys.delete ct
      @port_keys.delete clientPort
      @socket_keys.delete socket
      #broadcast_message(socket, "LEAVE", [handle])
    end
    super(clientPort)
  end
  def starting
    log("GlobalChat2 Server Running")
    super
  end
  # doesnt happen.. quits
  #def stopping
  #  log("Stopping.")
  #  #super
  #end
  
  def serve(io)
    loop do
      data = ""
      begin
        while line = io.recv(1)
          break if line == "\0" 
          data += line
        end
      rescue
          log "socket quit"
          socket = io
          @sockets.delete socket
          ct = @socket_keys[socket]
          handle = @handle_keys[ct]
          @handles.delete handle
          @handle_keys.delete ct
          @socket_keys.delete socket
          broadcast_message(socket, "LEAVE", [handle])
      end
      unless data == ""
        log "#{data}"
        parse_line(data, io)
      end
    end
  end
  
  def log(msg)
    #NSLog(msg.inspect)
    puts msg #unless msg == ""
  end
end


def ping_nexus(chatnet_name, host, port)
  puts "Pinging NexusNet that I'm Online!!"
  uri = URI.parse("http://nexusnet.herokuapp.com/online")
  query = {:name => chatnet_name, :port => port, :host => host}
  uri.query = URI.encode_www_form( query )
  Net::HTTP.get(uri)
  @published = true
end

def nexus_offline
  puts "Informing NexusNet that I have exited!!!"
  Net::HTTP.get_print("nexusnet.herokuapp.com", "/offline")
end

at_exit do
  nexus_offline
end

gc = GlobalChatServer.new(9994, '0.0.0.0', 1000, $stderr, true)
gc.password = "" # set a password here
gc.start
gc.join

ping_nexus("MyChatServer", "myhost.com", gc.port)


