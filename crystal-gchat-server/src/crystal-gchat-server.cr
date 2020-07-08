require "socket"
require "random"

class GlobalChatServer

  @sockets = [] of TCPSocket
  @handles = [] of String
  @handle_keys = {} of String => String # stores handle
  @socket_keys = {} of TCPSocket => String # stores chat_token
  @socket_by_handle = {} of String => TCPSocket # get socket by handle
  # @port_keys = {} # unnecessary in PING design
  @handle_last_pinged = {} of String => Time # used for clone removal
  @buffer = [] of Array(String)
  @password = "" # edit for password
  @server_name = "GC-crystal"
  @public_keys = {} of String => String
  @scrollback = true

  def handle_client(client)
    begin
      while message = client.gets("\0")
        puts "Client: #{message}"

        parse_line(message.gsub("\0", ""), client)
      end
    rescue IO::Error
      client.close
    end
    # client.puts message
    puts "socket disconnected"
    remove_dead_socket(client)

  end

  def parse_line(line, io)
    parr = line.split("::!!::")
    command = parr[0]
    # puts command
    if command == "SIGNON"
      handle = parr[1]
      password = parr[2] if parr.size > 2
      if !@handles.size == 0 && @handles.includes?(handle)
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
        chat_token = Random.new.hex
        @handle_keys[chat_token] = handle
        @socket_keys[io] = chat_token
        @socket_by_handle[handle] = io
        # @port_keys[io.peeraddr[1]] = chat_token
        # not on list until pinged.
        @handles << handle
        @sockets << io
        send_message(io, "TOKEN", [chat_token, handle, @server_name])
        broadcast_message(io, "JOIN", [handle])
      else
        send_message(io, "ALERT", ["Password is incorrect."])
        io.close
      end
      return
    end


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
        unless @handles.includes?(handle)
          @handles << handle
        end
        @handle_last_pinged[handle] = Time.utc
        spawn do
          sleep 5
          send_message(io, "PONG", [build_handle_list])
        end
      elsif command == "SIGNOFF"
        broadcast_message(nil, "LEAVE", [handle])
      elsif command == "PUBKEY"
        # broadcast user's pub key and store it
        pub_key = parr[1]
        @public_keys[handle] = pub_key
        broadcast_message(nil, "PUBKEY", [pub_key, handle])
      elsif command == "PRIVMSG"
        handleTo = parr[1] # handle to send to
        message = parr[2]
        socket = @socket_by_handle[handleTo]
        send_message(socket, "PRIVMSG", [handle, message])
      elsif command == "GETPUBKEYS"
        @public_keys.keys.each do |key|
          handle = key
          public_key = @public_keys[key]
          send_message(io, "PUBKEY", [public_key, handle])
        end
      end
    end


  end

  def send_message(io, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send io, msg
  end

  def broadcast_message(sender, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    broadcast msg, sender
  end

  def broadcast(message, sender=nil)
    @sockets.each do |socket|
      begin
        sock_send(socket, message) unless socket == sender
      rescue
        log "broadcast fail removal event"
        remove_dead_socket socket
      end
    end
  end

  def remove_dead_socket(socket)
    @sockets.delete socket
    ct = @socket_keys[socket]
    handle = @handle_keys[ct]
    @handles.delete handle
    @handle_keys.delete ct
    @socket_keys.delete socket
    @socket_by_handle.delete handle
  end

  # Send to a single socket
  # Params:
  # +io+:: Sending socket
  # +msg+:: Entirety of command sans the null terminator
  def sock_send(io, msg)
    msg = "#{msg}\0"
    log "Server: #{msg}"
    io << msg
  end

  def initialize
    @server = TCPServer.new("0.0.0.0", 9994)
    while client = @server.accept?
      spawn handle_client(client)
    end
  end

  def log(msg)
    puts(msg)
  end

  def build_handle_list
    return @handles.uniq.join("\n")
  end

  def check_token(chat_token)
    sender = @handle_keys[chat_token]
    return !sender.nil?
  end

  def get_handle(chat_token)
    sender = @handle_keys[chat_token]
    return sender
  end

  def build_chat_log
    return "" unless @scrollback
    output = ""
    displayed_buffer = @buffer.size > 30 ? @buffer[@buffer.size-30..-1] : @buffer
    displayed_buffer.each do |msg|
      output += "#{msg[0]}: #{msg[1]}\n"
    end
    return output
  end

end

gcs = GlobalChatServer.new