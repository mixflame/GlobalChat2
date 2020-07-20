require "socket"
require "random"
require "uri"
require "http/client"
require "yaml"
require "crypto/bcrypt/password"

class GlobalChatServer

  @sockets = [] of OpenSSL::SSL::Socket::Server
  @handles = [] of String
  @handle_keys = {} of String => String # stores handle
  @socket_keys = {} of OpenSSL::SSL::Socket::Server => String # stores chat_token
  @socket_by_handle = {} of String => OpenSSL::SSL::Socket::Server # get socket by handle
  # @port_keys = {} # unnecessary in PING design
  @handle_last_pinged = {} of String => Time # used for clone removal
  @buffer = [] of Array(String)
  @password = ""       # use change-password to change this
  @admin_password = "" # change for admin ability
  @server_name = "GC-crystal"
  @public_keys = {} of String => String
  @scrollback = true
  @buffer_line_limit = 100
  @port = 9994
  @is_private = false
  @canvas_size = "1280x690"
  @points = [] of String
  @admins = [] of String # warning, this controls admin
  @banned = {} of String => String
  @banned_ips = [] of String
  @ban_length = {} of String => Time

  def handle_client(client)
    ssl_socket = OpenSSL::SSL::Socket::Server.new(client, @context)
    
    ip = ssl_socket.remote_address.to_s
    if(@ban_length[ip]? && @ban_length[ip] > Time.utc)
      puts "denying banned ip, time left: #{(@ban_length[ip] - Time.utc).to_i} seconds"
      send_message(ssl_socket, "ALERT", ["You are banned. Time left: #{(@ban_length[ip] - Time.utc).to_i} seconds"])
      ssl_socket.close
      remove_dead_socket(ssl_socket)
      return
    elsif !@ban_length[ip]?
      if(@banned_ips.includes?(ip))
        puts "denying banned ip"
        send_message(ssl_socket, "ALERT", ["You are banned."])
        ssl_socket.close
        remove_dead_socket(ssl_socket)
        return
      end
    end
    begin
      while message = ssl_socket.gets("\0")
        
        puts "Client: #{message}"

        parse_line(message.gsub("\0", ""), ssl_socket)
      end
    rescue IO::Error
      ssl_socket.close
    end
    # client.puts message
    puts "socket disconnected"
    remove_dead_socket(ssl_socket)

  end

  def welcome_handle(io, handle)
    chat_token = Random.new.hex
    @handle_keys[chat_token] = handle
    @socket_keys[io] = chat_token
    @socket_by_handle[handle] = io
    @handles << handle
    @sockets << io
    send_message(io, "TOKEN", [chat_token, handle, @server_name])
    send_message(io, "CANVAS", [@canvas_size, @points.size])
    broadcast_message(io, "JOIN", [handle])
  end

  def parse_line(line, io)
    parr = line.split("::!!::")
    command = parr[0]
    # puts command
    if command == "SIGNON"
      handle = parr[1]
      password = parr[2] if parr.size > 2
      if @handles.includes?(handle)
        send_message(io, "ALERT", ["Your handle is in use."])
        io.close
        return
      end
      if handle == nil || handle == ""
        send_message(io, "ALERT", ["You cannot have a blank name."])
        # remove_dead_socket io
        io.close
        return
      end
      bcrypt_pass = Crypto::Bcrypt::Password.new(@password)
      bcrypt_admin_pass = Crypto::Bcrypt::Password.new(@admin_password)
      if bcrypt_admin_pass.verify(password.to_s)
        @admins << handle
        puts "admins: #{@admins}"
        # uuid are guaranteed unique
        welcome_handle(io, handle)
      else
        if bcrypt_pass.verify(password.to_s)
          # uuid are guaranteed unique
          welcome_handle(io, handle)
        else
          send_message(io, "ALERT", ["Password is incorrect."])
          io.close
        end
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
        File.write("messages.txt", "#{handle}: #{msg}\n", mode: "a")
        broadcast_message(io, "SAY", [handle, msg])
      elsif command == "PING"
        unless @handles.includes?(handle)
          @handles << handle
        end
        @handle_last_pinged[handle] = Time.utc
        spawn do
          sleep 5
          # clean_handles
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
        File.write("buffer.txt", "#{@points.last}\n", mode: "a")
      elsif command == "GETPOINTS"
        send_points(io)
      elsif command == "CLEARCANVAS"
        return unless @admins.includes?(handle) # admin function
        if File.exists?("buffer.txt")
          File.delete("buffer.txt")
        end
        @points = [] of String
        broadcast_message(nil, "CLEARCANVAS", [handle])
      elsif command == "DELETELAYERS"
        return unless @admins.includes?(handle) # admin function
        handle_to_delete = parr[1]
        delete_layers(handle_to_delete)
        broadcast_message(nil, "DELETELAYERS", [handle_to_delete])
      elsif command == "BAN"
        return unless @admins.includes?(handle) # admin function
        handle_to_ban = parr[1]
        
        if(parr.size > 3)
          time_length = parr[2]
          time_length = time_length.chomp.to_i.minutes
          # puts "banning #{handle_to_ban} for #{time_length.to_i} seconds"
          socket = @socket_by_handle[handle_to_ban]
          ip = socket.remote_address.to_s
          
          @banned[handle_to_ban] = ip
          if typeof(time_length) == Time::Span
            @ban_length[ip] = Time.utc + Time::Span.new(seconds: time_length.to_i)
          end
          @banned_ips << ip
          socket.close
          remove_dead_socket(socket)
        else
          puts "banning #{handle_to_ban} forever"
          socket = @socket_by_handle[handle_to_ban]
          ip = socket.remote_address.to_s
          
          @banned[handle_to_ban] = ip
          @banned_ips << ip
          socket.close
          remove_dead_socket(socket)
        end
      elsif command == "UNBAN"
        return unless @admins.includes?(handle) # admin function
        handle_to_unban = parr[1]
        ip = @banned[handle_to_unban]
        @banned_ips.reject! { |banned| banned == ip}
        @banned.delete handle_to_unban if @banned.includes?(handle_to_unban)
        @ban_length.delete ip if @ban_length.has_key?(ip)
      end
    end
  end

  def delete_layers(handle)
    @points.reject! { |p| p.split("::!!::").last == handle }

    File.write("buffer.txt", @points.join("\n"), mode: "w")
  end

  def send_points(io)
    # points_str = ""
    spawn do
      @points.each do |point|
        # points_str += "#{point}\0"
        sock_send(io, "#{point}\0")
        # sleep 0.seconds
        # Fiber.yield
      end
      send_message(io, "PONG", [build_handle_list])
    end

    # sock_send(io, points_str)
  end

  # def clean_handles
  #   @handle_keys.each do |k, v|
  #     if @handle_last_pinged[v] && @handle_last_pinged[v] < Time.utc - 30.seconds
  #       log "removed clone handle: #{v}"
  #       remove_user_by_handle(v)
  #     end
  #   end
  # end

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

  def broadcast(message, sender = nil)
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
    @admins.delete handle if @admins.includes?(handle)
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

  def sock_send(io, msg)
    msg = "#{msg}\0"
    # log "Server: #{msg}"
    io << msg
  end

  def initialize
    read_config
    load_canvas_buffer
    load_text_buffer
    unless @is_private == true
      ping_nexus(@server_name, @port)
    end
    status
    @server = TCPServer.new("0.0.0.0", @port)
    @context = OpenSSL::SSL::Context::Server.new
    @context.private_key = "MyKey.key"
    @context.certificate_chain = "MyCertificate.crt"


    while client = @server.accept?
      spawn handle_client(client)
    end
  end

  def finalize
    nexus_offline
  end

  def load_canvas_buffer
    if File.exists?("buffer.txt")
      @points = File.read("buffer.txt").chomp.split("\n")
    end
  end

  def load_text_buffer
    if File.exists?("messages.txt")
      lines = File.read("messages.txt").chomp.split("\n")
      lines.each do |line|
        @buffer << [line.split(": ").first, line.split(": ").last]
      end
    end
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
    displayed_buffer = @buffer.size > @buffer_line_limit ? @buffer[@buffer.size - @buffer_line_limit..-1] : @buffer
    displayed_buffer.each do |msg|
      output += "#{msg[0]}: #{msg[1]}\n"
    end
    return output
  end

  def ping_nexus(chatnet_name, port)
    puts "Pinging NexusNet that I'm Online!!"

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

  def read_config
    if File.exists?("config.yml")
      puts "reading config from config.yml"

      yaml = File.open("config.yml") do |file|
        YAML.parse(file)
      end

      @server_name = yaml["server_name"].as_s
      @port = yaml["port"].as_i
      @password = yaml["password"].as_s             # bcrypted
      @admin_password = yaml["admin_password"].as_s # bcrypted
      @is_private = yaml["is_private"].as_bool
      @canvas_size = yaml["canvas_size"].as_s
      @scrollback = yaml["scrollback"].as_bool
      @buffer_line_limit = yaml["buffer_line_limit"].as_i
    else
      puts "Use the change-password command to create config.yml"
    end
  end
end

gcs = GlobalChatServer.new
