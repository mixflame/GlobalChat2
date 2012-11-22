class GlobalChatController < Qt::Object

  attr_accessor :chat_token,
  :chat_buffer,
  :handles_list,
  :nicks,
  :handle,
  :handle_text_field,
  :connect_button,
  :server_list_window,
  :chat_window,
  :chat_window_text,
  :chat_message,
  :application,
  :scroll_view,
  :last_scroll_view_height,
  :host,
  :port,
  :password,
  :ts

  signals :updateChatViews


  def sendMessage
    @message = self.chat_message.text
    if @message != ""
      post_message(@message)
      self.chat_message.text = ''
    end
  end

  def scroll_the_scroll_view_down
    # FIXME QT
  end

  def sign_on
    #log "Connecting to: #{@host} #{@port}"
    begin
      @ts = TCPSocket.open(@host, @port)
    rescue
      log("Could not connect to GlobalChat server. Will retry in 5 seconds.")
      sleep 5
      #return false
      autoreconnect
    end
    @last_ping = Time.now # fake ping
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
    $autoreconnect = true
    true
  end

  def autoreconnect
    unless $autoreconnect == false
      # loop do
      #   if sign_on
      #     break
      #   end
      # end
      sign_on
    end
  end

  def return_to_server_list
    #@mutex.synchronize do
    # ret = MessageBox::no_icon(self, tr("Sorry"),
    # tr("GlobalChat connection crashed."),
    # MessageBox::Ok,
    # MessageBox::Ok)
    log "GlobalChat connection crashed."
    # $gc.hide
    # $sl.show
    #end
  end

  def update_and_scroll
    emit updateChatViews
    #scroll_the_scroll_view_down
  end

  def begin_async_read_queue
    @mutex = Mutex.new
    Thread.new do
      loop do
        #sleep 0.1
        data = ""
        # begin
        while line = @ts.recv(1)
          raise if @last_ping < Time.now - 30
          break if line == "\0"
          data += line
        end
        # rescue
        #   return_to_server_list
        #   break
        # end
        parse_line(data)
      end
    end
  end

  def parse_line(line)
    $stderr.print "#{line}\n"
    parr = line.split("::!!::")
    command = parr.first
    if command == "TOKEN"
      @chat_token = parr[1]
      @handle = parr[2]
      @server_name = parr[3]
      log "Connected to #{@server_name} \n"
      #ping
      get_handles
      $connected = true

    elsif command == "PONG"
      @nicks = parr.last.split("\n")
      @handles_list.clear
      @nicks.each do |nick|
        @handles_list.add_item(nick)
      end
      ping
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n")
      @nicks.each do |nick|
        @handles_list.add_item(nick)
      end
      get_log
    elsif command == "BUFFER"
      puts "got log"
      buffer = parr[1]
      unless buffer == "" || buffer == nil
        @chat_buffer = buffer
        update_and_scroll
        #output_to_chat_window(buffer)
      end
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      self.nicks << handle
      output_to_chat_window("#{handle} has entered\n")
      @handles_list.add_item(handle)
    elsif command == "LEAVE"
      handle = parr[1]
      output_to_chat_window("#{handle} has exited\n")
      self.nicks.delete(handle)
      @handles_list.remove_item(handle)
    elsif command == "ALERT"
      # if you get an alert
      # you logged in wrong
      # native alerts
      # are not part of
      # chat experience
      text = parr[1]
      alert(text)

      # return_to_server_list
    end
  end


  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send @ts, msg
  end

  def alert(msg)
    Qt::MessageBox.information(self, "Alert!", msg)
  end

  def sock_send io, msg
    # begin
    $stderr.print "#{msg}\n"
    msg = "#{msg}\0"
    io.send msg, 0
    # rescue
    # return_to_server_list
    # end
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(self.handle, message)
  end

  def add_msg(handle, message)
    # if @handle != handle && message.include?(@handle)
    #   QApplication::beep
    # end
    msg = "#{handle}: #{message}\n"
    output_to_chat_window(msg)
  end

  def get_log
    send_message "GETBUFFER", [@chat_token]
  end

  def get_handles
    send_message "GETHANDLES", [@chat_token]
  end

  def sign_out
    send_message "SIGNOFF", [@chat_token]
    @ts.close
  end

  def ping
    @last_ping = Time.now
    send_message("PING", [@chat_token])
  end

  def log str
    puts str
    #output_to_chat_window(str)
  end

  def output_to_chat_window str
    @mutex.synchronize do
      @chat_buffer += "#{str}"
      update_and_scroll
    end
  end

end