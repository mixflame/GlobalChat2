#!/usr/bin/env ruby

# A chat server with a custom protocol and roomless design
#
# Author::    Jonathan Silverman  (mailto:jsilverman2@gmail.com)
# Copyright:: Copyright (c) 2012 Jonathan Silverman
# License::   GPLv3

# GlobalChatServer is the GServer class

require 'gserver'
require 'net/http'
require 'uri'
require 'securerandom'
require 'pstore'

class WordGenerator
  VOGALS = %w(a e i o u y)
  CONSONANTS = [*?a..?z] - VOGALS
  MOD_RESULT = [0, 1].freeze


  def initialize(length)
    @length = length
    @mod_result = MOD_RESULT.sample
  end

  def generate
    length.times.map { |i| i % 2 == mod_result ? CONSONANTS.sample : VOGALS.sample }.join
  end

  private

  attr_reader :length, :mod_result
end

class GlobalChatServer < GServer

  attr_accessor :handles, :buffer, :handle_keys, :sockets, :password, :socket_keys, :scrollback, :server_name, :is_private, :host

  # Boot the server
  # Params:
  # +port+:: listening port
  # +args+:: GServer args
  def initialize(port, *args)
    super(port, *args)
    self.audit = true
    self.debug = true
    Dir.mkdir "data" unless Dir.exists? "data"
    @pstore = PStore.new("data/gchat.pstore")
    @handle_keys = {} # stores handle
    @socket_keys = {} # stores chat_token
    @socket_by_handle = {} # get socket by handle
    # @port_keys = {} # unnecessary in PING design
    @handle_last_pinged = {} # used for clone removal
    @handles = []
    @sockets = []
    @buffer = []

    load_chat_log
    @mutex = Mutex.new

    ObjectSpace.define_finalizer(self,
    self.class.method(:finalize).to_proc)
  end

  def self.create(name, host, port, is_private, replay)
    gc = new(port, host, 1000, $stderr, true)
    gc.server_name = name
    gc.host = host
    gc.scrollback = replay
    gc.is_private = is_private
    gc.start
    unless is_private == true
      gc.ping_nexus(gc.server_name, host, port)
    end
    gc.status
    gc.join
    # gc
  end

  def GlobalChatServer.finalize(id)
    puts "GlobalChatServer #{id} dying at #{Time.new}"
    unless @private == true
      gc.nexus_offline(gc.server_name)
    end
    save_chat_log
  end

  # Broadcast a command to every connected client
  # Params:
  # +message+:: the command to send
  # +sender+:: the sending socket, used to not self-broadcast
  def broadcast(message, sender=nil)
    @mutex.synchronize do
      @sockets.each do |socket|
        begin
          sock_send(socket, message) unless socket == sender
        rescue
          log "broadcast fail removal event"
          remove_dead_socket socket
        end
      end
    end
  end

  # Remove an inactive user by their socket
  # Params:
  # +socket+:: The "dead" socket
  def remove_dead_socket(socket)
    @sockets.delete socket
    ct = @socket_keys[socket]
    handle = @handle_keys[ct]
    @handles.delete handle
    @handle_keys.delete ct
    @socket_keys.delete socket
  end

  # Used to remove an inactive user by their handle
  # Params:
  # +handle+:: inactive user's handle
  def remove_user_by_handle(handle)
    ct = @handle_keys.key(handle)
    socket = @socket_keys.key(ct)
    @sockets.delete socket

    @handles.delete handle
    @handle_keys.delete ct
    @socket_keys.delete socket
    begin
      broadcast_message(socket, "LEAVE", [handle])
    rescue
      log "failed to broadcast LEAVE for clone handle #{handle}"
    end
  end

  # Checks if a token even exists
  # Params:
  # +chat_token+:: User's chat token, given on TOKEN command
  def check_token(chat_token)
    sender = @handle_keys[chat_token]
    return !sender.nil?
  end

  # Returns the user's true handle from a token, security measure
  # Params:
  # +chat_token+:: User's chat token, given on TOKEN command
  def get_handle(chat_token)
    sender = @handle_keys[chat_token]
    return sender
  end

  # Send to a single socket a "message"
  # Params:
  # +io+:: Sending socket
  # +opcode+:: The command opcode
  # +args+:: The command arguments i.e. [argument, @chat_token]
  def send_message(io, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send io, msg
  end

  # Send to a single socket
  # Params:
  # +io+:: Sending socket
  # +msg+:: Entirety of command sans the null terminator
  def sock_send io, msg
    msg = "#{msg}\0"
    log "Server: #{msg}"
    io.send msg, 0
  end

  # Send to all connected sockets a "message"
  # Params:
  # +sender+:: Don't broadcast me. Nil means do it for everyone.
  # +opcode+:: The command opcode
  # +args+:: The command arguments i.e. [argument, @chat_token]
  def broadcast_message(sender, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    broadcast msg, sender
  end

  # Respond to GETBUFFER. Create the log for BUFFER message.
  def build_chat_log
    return "" unless @scrollback
    out = ""
    displayed_buffer = @buffer.length > 30 ? @buffer[@buffer.length-30..-1] : @buffer
    displayed_buffer.each do |msg|
      out += "#{msg[0]}: #{msg[1]}\n"
    end
    return out
  end

  # Clean out any handles who have pinged, but not in 30 seconds (pretty fail-proof)
  def clean_handles
    @handle_keys.each do |k, v|
      if @handle_last_pinged[v] && @handle_last_pinged[v] < Time.now - 30
        log "removed clone handle: #{v}"
        remove_user_by_handle(v)
      end
    end
  end

  # Build handles list for GETHANDLES command
  def build_handle_list
    return @handles.uniq.join("\n")
  end

  # Called automatically, parses incoming commands for the server
  # Params:
  # +line+:: The command that was just sent
  # +io+:: The sending io
  def parse_line(line, io)
    parr = line.split("::!!::")
    command = parr[0]
    if command == "SIGNON"
      handle = parr[1]
      password = parr[2]
      if !@handles.length == 0 && @handles.include?(handle)
        send_message(io, "ALERT", ["Your handle is in use."])
        io.close
        return
      end
      if handle == nil || handle == ""
        send_message(io, "ALERT", ["You cannot have a blank name."])
        #remove_dead_socket io
        io.close
        return
      end
      if ((@password == password) || ((password === nil) && (@password == "")))
        # uuid are guaranteed unique
        chat_token = rand(36**8).to_s(36)
        @mutex.synchronize do
          @handle_keys[chat_token] = handle
          @socket_keys[io] = chat_token
          @socket_by_handle[handle] = io
          # @port_keys[io.peeraddr[1]] = chat_token
          # not on list until pinged.
          @handles << handle
          @sockets << io
        end
        send_message(io, "TOKEN", [chat_token, handle, @server_name])
        broadcast_message(io, "JOIN", [handle])
      else
        send_message(io, "ALERT", ["Password is incorrect."])
        io.close
      end
      return
    end

    # auth
    chat_token = parr.last

    if check_token(chat_token)
      handle = get_handle(chat_token)
      if command == "GETHANDLES"
        send_message(io, "HANDLES", [build_handle_list])
      elsif command == "GETBUFFER"
        buffer = build_chat_log
        send_message(io, "BUFFER", [buffer])
      elsif command == "MESSAGE"
        msg = parr[1]
        @buffer << [handle, msg]
        broadcast_message(io, "SAY", [handle, msg])
      elsif command == "PING"
        unless @handles.include?(handle)
          @handles << handle
        end
        @handle_last_pinged[handle] = Time.now
      elsif command == "SIGNOFF"
        broadcast_message(nil, "LEAVE", [handle])
      elsif command == "PUBKEY"
        # broadcast user's pub key and store it
        pub_key = parr[1]
        @public_keys ||= {}
        @public_keys[handle] = pub_key
        broadcast_message(nil, "PUBKEY", [pub_key, handle])
      elsif command == "PRIVMSG"
        handleTo = parr[1] # handle to send to
        message = parr[2]
        socket = @socket_by_handle[handleTo]
        send_message(socket, "PRIVMSG", [handle, message])
      elsif command == "GETPUBKEYS"
        @public_keys ||= {}
        @public_keys.keys.each do |key|
          handle = key
          public_key = @public_keys[key]
          send_message(io, "PUBKEY", [public_key, handle])
        end
      end
    end
  end

  # Send everyone "PONG" command so they can register for clone-cleaning
  def pong_everyone
    #log "trying to pong"
    if @sockets.length > 0 && !self.stopped?
      #log "ponging"
      broadcast_message(nil, "PONG", [build_handle_list])
      #sleep 5
      clean_handles
    end
  end

  # Start PONGing all connected clients, and saving my log, every 5s
  def start_pong_loop
    Thread.new do
      loop do
        sleep 5
        # log "pong all"
        pong_everyone
        # log "pong logsave"
        save_chat_log
      end
    end
  end

  #  def disconnecting(clientPort)
  #    log "disconnect event"
  #    ct = @port_keys[clientPort]
  #    handle = @handle_keys[ct]
  #    if handle
  #      log "disconnect removal event"
  #      remove_dead_socket ct
  #    end
  #    super(clientPort)
  #  end

  # Hook GServer's starting method to start the PONGer
  def starting
    log("GlobalChat2 Server Running")
    start_pong_loop
  end

  # Hook GServer's serve method to process and serve commands
  def serve(io)
    loop do
      data = ""
      begin
        while line = io.recv(1)
          break if line == "\0"
          data += line
        end
      rescue
        log "recv break removal event"
        remove_dead_socket io #, true
        break
      end
      unless data == ""
        log "Client: #{data}"
        parse_line(data, io)
      end
    end
  end

  # Get the server status. Informational.
  def status
    passworded = (self.password != "")
    scrollback = self.scrollback
    log "#{@server_name} running on GlobalChat2 3.0 platform Replay:#{scrollback} Passworded:#{passworded}"
  end

  # Logging method, used however
  # Params:
  # +msg+:: what to log
  def log(msg)
    # puts msg
    $stdout.write("#{msg}\n")
  end

  # Persist my chat buffer to disk
  def save_chat_log
    # log "saving chatlog"
    @pstore.transaction do
      @pstore[:log] = @buffer
      #p @pstore[:log]
    end

  end

  # Load my saved chat buffer
  def load_chat_log
    # log "loading chatlog"
    @pstore.transaction(true) do
      @buffer = @pstore[:log] || []
      #p @buffer
    end
  end

  # Tell the Nexus I am online
  # Params:
  # +chatnet_name+:: The name of my chat server
  # +host+:: Hostname of chat server
  # +port+:: The listening port
  def ping_nexus(chatnet_name, host, port)
    puts "Pinging NexusNet that I'm Online!!"
    uri = URI.parse("http://nexus-msl.herokuapp.com/online?name=#{chatnet_name}&port=#{port}")
    #query = {:name => chatnet_name, :port => port, :host => host}
    #uri.query = URI.encode_www_form( query )
    Net::HTTP.get(uri)
    $published = true
  end

  # Tell Nexus I am no longer online
  def nexus_offline(chatnet_name)
    puts "Informing NexusNet that I have exited!!!"
    Net::HTTP.get_print("nexusnet.herokuapp.com", "/offline")
  end


end



#Thread.new do
GlobalChatServer.create("GC-#{WordGenerator.new(10).generate}", "0.0.0.0", 9994, false, true)
#end
