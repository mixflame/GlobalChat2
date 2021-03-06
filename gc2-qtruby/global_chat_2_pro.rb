#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'Qt4'
require 'qtuitools'
require 'net/http'
require 'socket'
require 'thread'
require 'pstore'


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
  :ts,
  :server_name

  signals :updateChatViews, :updateTitles, :beep


  def sendMessage
    begin
      @message = self.chat_message.text
      if @message != ""
        post_message(@message)
        self.chat_message.text = ''
      end
    rescue
      autoreconnect
    end
  end

  def sign_on
    #log "Connecting to: #{@host} #{@port}"
    begin
      @ts = TCPSocket.open(@host, @port)
    rescue
      log("Could not connect to GlobalChat server. Will retry in 5 seconds.")
      return false
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
      loop do
        sleep 5
        if sign_on
          break
        end
      end
    end
  end

  def return_to_server_list
    #@mutex.synchronize do
    alert "GlobalChat connection crashed."
    $gc.hide
    $sl.show
    #end
  end

  def update_and_scroll
    emit updateChatViews
  end

  def begin_async_read_queue
    @mutex = Mutex.new
    Thread.new do
      loop do
        #sleep 0.1
        data = ""
        begin
          while line = @ts.recv(1)
            # pongout disconnect reconnect below...
            #raise if @last_ping < Time.now - 120 # opted out
            break if line == "\0"
            data += line
          end
        rescue
          autoreconnect
          break
        end
        data = data.force_encoding("UTF-8")
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
      emit updateTitles
      output_to_chat_window "Connected to #{@server_name} \n"
      ping
      get_handles
      $connected = true
    elsif command == "PONG"
      @nicks = parr.last.split("\n").uniq
      @handles_list.clear
      @nicks.each do |nick|
        @handles_list.add_item(nick)
      end
      ping
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n").uniq
      @handles_list.clear
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

      return_to_server_list
    end
  end


  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    msg = msg.force_encoding("UTF-8")
    sock_send @ts, msg
  end

  def alert(msg)
    Qt::MessageBox.critical(self, "Alert!", msg)
  end

  def sock_send io, msg
    begin
      $stderr.print "#{msg}\n"
      msg = "#{msg}\0"
      io.send msg, 0
    rescue
      autoreconnect
    end
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(self.handle, message)
  end

  def add_msg(handle, message)
    if @handle != handle && message.include?(@handle)
      emit beep
    end
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



class ServerList < Qt::Widget

  signals :updateTitle

  def initialize(parent=nil)
    super parent
    loader = Qt::UiLoader.new
    file = Qt::File.new 'ServerList.ui' do
      open Qt::File::ReadOnly
    end
    window = loader.load file
    file.close

    @pstore = PStore.new("gchat2pro.pstore")

    @sl = window.findChild(Qt::ListWidget, "listWidget")
    @handle = window.findChild(Qt::LineEdit, "lineEdit")
    @host = window.findChild(Qt::LineEdit, "lineEdit_2")
    @port = window.findChild(Qt::LineEdit, "lineEdit_3")
    @password = window.findChild(Qt::LineEdit, "lineEdit_4")
    @refresh = window.findChild(Qt::PushButton, "pushButton")
    @connect = window.findChild(Qt::PushButton, "pushButton_2")

    @sl.connect(SIGNAL "currentTextChanged(const QString&)") { |item| get_info(item) }
    @refresh.connect(SIGNAL :clicked) { refresh }
    @connect.connect(SIGNAL :clicked) { connect }

    self.layout = Qt::VBoxLayout.new do |l|
      l.addWidget(window)
    end

    self.windowTitle = tr("Server List")

    get_servers

    load_prefs
  end

  def refresh
    @sl.clear
    get_servers
  end

  def load_prefs
    begin
      @pstore.transaction do
        @handle.text = @pstore["handle"] || ""
        @host.text = @pstore["host"] || ""
        @port.text = @pstore["port"] || ""
      end
    rescue
      puts "no pstore yet"
    end
  end

  def save_prefs
    @pstore.transaction do
      @pstore["handle"] = @handle.text
      @pstore["host"] = @host.text
      @pstore["port"] = @port.text
    end
  end

  def get_info(name)
    if name != "" && name != nil
      row = @names.index(name)
      @host.text = @server_list_hash[row][:host]
      @port.text = @server_list_hash[row][:port]
    end
  end


  def get_servers

    Thread.new do
      @server_list_hash = Net::HTTP.get('nexusnet.herokuapp.com', '/msl').
      split("\n").
      collect do |s|
        par = s.split("-!!!-")
        {:host => par[1], :name => par[0], :port => par[2]}
      end


      @names = @server_list_hash.map { |i| i[:name] }

      update_servers
    end

  end

  def update_servers
    @sl.clear
    @names.each do |name|
      @sl.add_item(name)
    end
  end


  def connect
    # save defaults
    save_prefs
    self.hide
    gc = GlobalChat.new(@handle.text, @host.text, @port.text, @password.text)
    gc.show
  end

end


class GlobalChat < Qt::Widget

  attr_accessor :handles, :chat_window_text, :chat_message, :gcc

  def initialize(handle, host, port, password, parent=nil)
    super parent

    block=Proc.new{ Thread.pass }
    timer=Qt::Timer.new(window)
    invoke=Qt::BlockInvocation.new(timer, block, "invoke()")
    Qt::Object.connect(timer, SIGNAL("timeout()"), invoke, SLOT("invoke()"))
    timer.start(1)

    loader = Qt::UiLoader.new
    file = Qt::File.new 'GlobalChat.ui' do
      open Qt::File::ReadOnly
    end
    window = loader.load file
    file.close

    @handles_list = window.findChild(Qt::ListWidget, "listWidget")
    @chat_window_text = window.findChild(Qt::TextEdit, "textEdit")
    @chat_message = window.findChild(Qt::LineEdit, "lineEdit")

    self.layout = Qt::VBoxLayout.new do |l|
      l.addWidget(window)
    end

    self.windowTitle = tr("GlobalChat")

    # UI ETC
    @chat_message.connect(SIGNAL :returnPressed) { @gcc.sendMessage }
    @handles_list.connect(SIGNAL "currentTextChanged(const QString&)") { |item| foghornMe(item) }

    @gcc = GlobalChatController.new

    @gcc.connect(SIGNAL :updateChatViews) { updateChatViews }
    @gcc.connect(SIGNAL :updateTitles) { updateTitles }
    @gcc.connect(SIGNAL :beep) { beep }

    at_exit do
      @gcc.sign_out
    end

    # binding.pry
    Thread.new do
      @gcc.handle = handle
      @gcc.host = host
      @gcc.port = port
      @gcc.password = password
      @gcc.nicks = []
      @gcc.chat_buffer = ""
      @gcc.handles_list = @handles_list
      @gcc.chat_message = @chat_message
      @gcc.chat_window_text = @chat_window_text
      @gcc.autoreconnect unless @gcc.sign_on
    end

  end

  def foghornMe(name)
    if !(name == "") && !(name == nil)
      @chat_message.text = "#{name}: "
      @chat_message.setFocus
    end
  end

  def beep
    puts "\a"
  end

  def updateTitles
    self.windowTitle = @gcc.server_name
  end

  def updateChatViews
    @chat_window_text.text = @gcc.chat_buffer
    @chat_window_text.verticalScrollBar.setSliderPosition(@chat_window_text.verticalScrollBar.maximum)
  end

end


app = Qt::Application.new ARGV
# Qt.debug_level = Qt::DebugLevel::High
sl = ServerList.new
sl.show
app.exec