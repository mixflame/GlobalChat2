require "socket"
require "random"
require "uri"
require "http/client"

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
  @port = 9994
  @is_private = false
  @canvas_size = "1280x690"
  @points = [] of String

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
        send_message(io, "CANVAS", [@canvas_size])
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
          clean_handles
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
      elsif command == "POINT"
        
        @points << line.gsub(parr.last, handle)
        x = parr[1]
        y = parr[2]
        dragging = parr[3]
        red = parr[4]
        green = parr[5]
        blue = parr[6]
        alpha = parr[7]
        width = parr[8]
        broadcast_message(io, "POINT", [x, y, dragging, red, green, blue, alpha, width, handle])
      elsif command == "GETPOINTS"
        send_points(io)
      end
    end


  end

  def send_points(io)
    points_str = ""
    @points.each do |point|
      points_str += "#{point}\0"
    end

    sock_send(io, points_str)
  end

  def clean_handles
    @handle_keys.each do |k, v|
      if @handle_last_pinged[v] && @handle_last_pinged[v] < Time.utc - 30.seconds
        log "removed clone handle: #{v}"
        remove_user_by_handle(v)
      end
    end
  end

  def send_message(io, opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    begin
      sock_send io, msg
    rescue
      log "sock send fail removal event"
      remove_dead_socket io
    end
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
    @sockets.delete socket if @sockets.includes?(socket)
    ct = @socket_keys[socket] if @socket_keys.has_key?(socket)
    handle = @handle_keys[ct] if @handle_keys.has_key?(ct)
    @handles.delete handle if @handles.includes?(handle)
    @handle_keys.delete ct if @handle_keys.has_key?(ct)
    @socket_keys.delete socket if @socket_keys.has_key?(socket)
    @socket_by_handle.delete handle if @socket_by_handle.has_key?(handle)

    begin
      broadcast_message(socket, "LEAVE", [handle])
    rescue
      log "failed to broadcast LEAVE for handle #{handle}"
    end
  end

  def remove_user_by_handle(handle)
    ct = @handle_keys.key_for(handle)
    socket = @socket_keys.key_for(ct)
    @sockets.delete socket if @sockets.includes?(socket)

    @handles.delete handle if @handles.includes?(handle)
    @handle_keys.delete ct if @handle_keys.has_key?(ct)
    @socket_keys.delete socket if @socket_keys.has_key?(socket)
    @socket_by_handle.delete handle if @socket_by_handle.has_key?(handle)
    begin
      broadcast_message(socket, "LEAVE", [handle])
    rescue
      log "failed to broadcast LEAVE for handle #{handle}"
    end
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
    unless @is_private == true
      ping_nexus(@server_name, @port)
    end
    status
    @server = TCPServer.new("0.0.0.0", @port)
    while client = @server.accept?
      spawn handle_client(client)
    end
  end

  def finalize
    nexus_offline
  end

  def status
    passworded = (@password != "")
    scrollback = @scrollback
    log "#{@server_name} running on GlobalChat2 platform Replay:#{scrollback} Passworded:#{passworded}"
  end

  def log(msg)
    puts(msg)
  end

  def build_handle_list
    return @handles.uniq.join("\n")
  end

  def check_token(chat_token)
    sender = @handle_keys[chat_token]?
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

  def ping_nexus(chatnet_name, port)
    puts "Pinging NexusNet that I'm Online!!"
    
    #query = {:name => chatnet_name, :port => port, :host => host}
    #uri.query = URI.encode_www_form( query )
    response = HTTP::Client.get "http://nexus-msl.herokuapp.com/online?name=#{chatnet_name}&port=#{port}"
    @published = true

    Signal::INT.trap do
      nexus_offline
      exit
    end
  
    at_exit do |status|
      nexus_offline
    end
  
  end

    # Tell Nexus I am no longer online
  def nexus_offline
    if @published == true
      puts "Informing NexusNet that I have exited!!!"
      response = HTTP::Client.get "http://nexus-msl.herokuapp.com/offline"
      @published = false
    end
  end

end

gcs = GlobalChatServer.new

