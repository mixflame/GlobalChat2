# DEATH TO MY HATERS

require 'gserver'

class GlobalChatServer < GServer
  
  attr_accessor :handles, :buffer, :handle_keys, :sockets, :password, :socket_keys
  
  def initialize(port=9994, *args)
    super(port, *args)
    self.audit = true
    @handle_keys = {}
    @socket_keys = {}
    @handles = []
    @sockets = []
    @buffer = []
    
    @mutex = Mutex.new
  end
  
  def broadcast(message, sender=nil)
    @mutex.synchronize do
      @sockets.each do |socket|
        begin
          socket.puts message unless socket == sender
        rescue
          @sockets.delete socket
          ct = @socket_keys[socket]
          handle = @handle_keys[ct]
          @handles.delete handle
          @handle_keys.delete ct
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
    NSLog(msg)
    io.puts msg
  end
  
  # server tell all sockets except
  def broadcast_message(sender, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    NSLog "broadcast: #{msg}"
    broadcast msg, sender
  end
  
  
  # react to allowed commands
  def parse_line(line, io)
    NSLog(line)
    parr = line.strip.split("::!!::")
    command = parr[0]
    if command == "SIGNON"
      handle = parr[1]
      password = parr[2]
      
      if (@password == password) || ((password === nil) && (@password == ""))
        
        chat_token = rand(36**8).to_s(36)
        @mutex.synchronize do
          @handle_keys[chat_token] = handle
          @socket_keys[io] = chat_token
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
  
  def serve(io)
    loop do
      line = io.readline
      parse_line(line, io)
    end
  end
  
  def connecting(client)
    super(client)
  end
  def disconnecting(clientPort)
    super(clientPort)
  end
  def starting
    log("Starting...")
    super
  end
  def stopping
    log("Stopping.")
    super
  end
  def log(msg)
    NSLog(msg)
  end
end
