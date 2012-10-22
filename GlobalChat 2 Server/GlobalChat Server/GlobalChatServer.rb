require 'gserver'

class GlobalChatServer < GServer
  
  attr_accessor :handles, :buffer, :handle_keys, :sockets, :password, :socket_keys, :scrollback
  
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
          log "broadcast fail removal event"
          remove_dead_socket socket
        end
      end
    end
  end

  def remove_dead_socket(socket, broadcast=false)
    @sockets.delete socket
    ct = @socket_keys[socket]
    handle = @handle_keys[ct]
    @handles.delete handle
    @handle_keys.delete ct
    @socket_keys.delete socket
    # dont wanna broadcast a LEAVE
    # in a dead socket cleanup function
    if broadcast
      broadcast_message(socket, "LEAVE", [handle])
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
  
  def build_chat_log
    return "" unless @scrollback
    out = ""
    @buffer.each do |msg|
      out += "#{msg[0]}: #{msg[1]}\n"
    end
    out
  end
  
  def build_handle_list
    @handles.join("\n")
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
        send_message(io, "TOKEN", [chat_token, handle])
        broadcast_message(io, "JOIN", [handle])
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
      log "disconnect removal event"
      remove_dead_socket ct #, true
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
          log "recv break removal event"
          remove_dead_socket io, true
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