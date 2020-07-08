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
  @buffer = [] of String
  @password = "" # edit for password
  @server_name = "GC-crystal"

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
    client.close
    if client.closed?
      @sockets.delete client
    end

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

end

gcs = GlobalChatServer.new