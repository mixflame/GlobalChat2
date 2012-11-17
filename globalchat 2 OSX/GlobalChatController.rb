require 'uri'
require 'socket'

module Notification
  module_function
  def send(title, text)
    notification = NSUserNotification.alloc.init
    notification.title = title
    notification.informativeText = text

    center = NSUserNotificationCenter.defaultUserNotificationCenter
    center.scheduleNotification(notification)
  end
end

class GlobalChatController

  attr_accessor :chat_token,
  :chat_buffer,
  :nicks,
  :handle,
  :handle_text_field,
  :connect_button,
  :server_list_window,
  :chat_window,
  :chat_window_text,
  :chat_message,
  :nicks_table,
  :application,
  :scroll_view,
  :last_scroll_view_height,
  :host,
  :port,
  :password,
  :ts,
  :msg_count,
  :last_pong,
  :ping_timer

  def initialize
    @mutex = Mutex.new
    @queue = Dispatch::Queue.new('com.jonsoft.globalchat')
    @sent_messages = []
    @sent_msg_index = 0
  end

  def quit(sender)
    if $connected == false
      @application.terminate(self)
    else
      return_to_server_list
    end
  end

  def tableView(view, objectValueForTableColumn:column, row:index)
    @nicks[index]
  end

  def numberOfRowsInTableView(view)
    @nicks.size
  end

  def cycle_chat_messages
    @chat_message.setStringValue @sent_messages[@sent_msg_index % @sent_messages.length]
  end

  def control(control, textView:fieldEditor, doCommandBySelector:commandSelector)
    if commandSelector.description == NSString.stringWithUTF8String("moveUp:")
      # up
      @sent_msg_index += 1
      cycle_chat_messages
      select_chat_text
      return true
    elsif commandSelector.description == NSString.stringWithUTF8String("moveDown:")
      # down
      @sent_msg_index -= 1
      cycle_chat_messages
      select_chat_text
      return true
    end

    return false

  end

  def cleanup
    @chat_message.setStringValue('')
    @nicks = []
    @nicks_table.reloadData
    @chat_window_text.setString(NSString.stringWithUTF8String(''))
  end

  def sendMessage(sender)
    begin
      @message = sender.stringValue
      if @message != ""
        post_message(@message)
        @chat_message.setStringValue('')
        @sent_messages << @message
      end
    rescue
      autoreconnect
    end
  end

  def foghornMe(sender)
    @chat_message.setStringValue("#{@nicks[sender.selectedRow]}: ")
    select_chat_text
  end

  def select_chat_text
    @chat_message.selectText self
    @chat_message.currentEditor.setSelectedRange(NSRange.new(@chat_message.stringValue.length,0))
  end

  def scroll_the_scroll_view_down
    #y = 0
    #currentScrollPosition = NSPoint.new
    frame_height = self.scroll_view.documentView.frame.size.height
    content_size = self.scroll_view.contentSize.height
    y = frame_height - content_size

    self.scroll_view.setDrawsBackground false

    #while currentScrollPosition.y < y #|| (self.chat_window_text.stringValue == "")
    #currentScrollPosition = self.scroll_view.contentView.bounds.origin
    #self.scroll_view.contentView.scrollToPoint(NSMakePoint(0, currentScrollPosition.y + 1))
    self.chat_window_text.scrollRangeToVisible NSRange.new(@chat_window_text.string.length, 0)
    self.scroll_view.reflectScrolledClipView(self.scroll_view.contentView)
    #end
  end

  def update_chat_views
    run_on_main_thread do
      @chat_window_text.setString(NSString.stringWithUTF8String(self.chat_buffer))
    end
  end

  def sign_on
    #cleanup
    #log "Connecting to: #{@host} #{@port}"
    begin
      @ts = TCPSocket.open(@host, @port)
    rescue
      #alert("Could not connect to GlobalChat server.")
      return false
    end
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
    true
  end

  def alert(msg)
    run_on_main_thread do
      alert = NSAlert.new
      alert.setMessageText(msg)
      alert.runModal
    end
  end

  def run_on_main_thread &block
    block.performSelectorOnMainThread "call:", withObject:nil, waitUntilDone:false
  end

  def autoreconnect
    unless $autoreconnect == false
      @queue.async do
        cleanup
        while sign_on == false
          output_to_chat_window "offline! autoreconnecting in 3 sec\n"
          sleep 3
        end
      end
    end
  end

  def return_to_server_list
    @mutex.synchronize do
      $autoreconnect = false
      self.server_list_window.makeKeyAndOrderFront(nil)
      self.chat_window.orderOut(self)
      cleanup
      @ts.close
      $connected = false
    end
  end

  def update_and_scroll
    update_chat_views
    scroll_the_scroll_view_down
  end

  def begin_async_read_queue
    @queue.async do
      loop do
        data = ""
        begin
          while line = @ts.recv(1)
            break if line == "\0"
            data += line
          end
        rescue
          autoreconnect
          break
        end

        p data
        parse_line(data)
      end
    end
  end

  def parse_line(line)
    parr = line.split("::!!::")
    command = parr.first
    if command == "TOKEN"
      @chat_token = parr[1]
      @handle = parr[2]
      @server_name = parr[3]
      ping
      @server_list_window.orderOut(self)
      @chat_window.makeKeyAndOrderFront(nil)
      if @server_name
        log "Connected to #{@server_name} \n"
        @chat_window.setTitle @server_name
      end
      get_handles
      get_log
      $connected = true

    elsif command == "PONG"
      @last_pong = Time.now
      @nicks = parr.last.split("\n")
      @nicks_table.reloadData
      ping
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n")
      @nicks_table.reloadData
    elsif command == "BUFFER"
      buffer = parr[1]
      unless buffer == "" || buffer == nil
        output_to_chat_window(buffer)
        sleep 0.1
        scroll_the_scroll_view_down
      end
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      output_to_chat_window("#{handle} has entered\n")
    elsif command == "LEAVE"
      handle = parr[1]
      output_to_chat_window("#{handle} has exited\n")
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
    sock_send @ts, msg
  end

  def sock_send io, msg
    begin
      p msg
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
      NSBeep()
      Notification.send(handle, message)
      NSApp.requestUserAttention 0
      @msg_count ||= 0
      @msg_count += 1
      NSApplication.sharedApplication.dockTile.setBadgeLabel(@msg_count.to_s)
    end
    msg = NSString.stringWithUTF8String("#{handle}: #{message}\n")
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
    send_message("PING", [@chat_token])
  end


  def p obj
    NSLog obj.description
  end

  def log str
    # NSLog str
    output_to_chat_window(str)
  end

  def output_to_chat_window str
    #@mutex.synchronize do
    @chat_buffer += "#{str}"
    update_and_scroll
    #end
  end

end
