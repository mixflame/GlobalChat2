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
  :last_ping,
  :away_nicks,
  :match_index

  def initialize
    @queue = Dispatch::Queue.new('com.jonsoft.globalchat')
    @sent_messages = [""]
    @sent_msg_index = 0
    @away_nicks = []
    @match_index = 0
  end

  def quit(sender)
    if $connected == false
      @application.terminate(self)
    else
      return_to_server_list
    end
  end

  def tableView(tv, willDisplayCell:cell, forTableColumn:col, row:the_row)
    if @away_nicks.include?(cell.stringValue)
      cell.setTextColor NSColor.grayColor
    else
      cell.setTextColor NSColor.blackColor
    end
  end

  def tableView(view, objectValueForTableColumn:column, row:index)
    @nicks.nil? ? nil : @nicks[index]
  end

  def numberOfRowsInTableView(view)
    @nicks.nil? ? 0 : @nicks.size
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
    elsif commandSelector.description == NSString.stringWithUTF8String("insertTab:")
      #tabby
      message = @chat_message.stringValue
      last_letters_before_tab = message.split(" ").last
      if !@last_match
        matches = @nicks.grep /^#{last_letters_before_tab}/
      else
        matches = @nicks.grep /^#{@last_match}/
      end
      @match_index += 1
      if matches.length > 0
        @match_index = @match_index % matches.length
        match = matches[@match_index]
        @chat_message.setStringValue message.reverse.sub(last_letters_before_tab.reverse, match.reverse).reverse
      end
      @last_match = last_letters_before_tab
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

  def select_chat_text
    @chat_message.selectText self
    @chat_message.currentEditor.setSelectedRange(NSRange.new(@chat_message.stringValue.length,0))
  end

  def update_chat_views
    run_on_main_thread do
      # @chat_window_text.setString(NSString.stringWithUTF8String(self.chat_buffer))
      frame_height = self.scroll_view.documentView.frame.size.height
      content_size = self.scroll_view.contentSize.height
      y = @chat_window_text.string.length
      self.scroll_view.setDrawsBackground false
      self.chat_window_text.scrollRangeToVisible NSRange.new(y, 0)
      self.scroll_view.reflectScrolledClipView(self.scroll_view.contentView)
    end
  end

  def parse_links
    run_on_main_thread do
      @chat_window_text.setEditable(true)
      @chat_window_text.setAutomaticLinkDetectionEnabled(true)
      @chat_window_text.textStorage.setAttributedString(NSAttributedString.new.initWithString(NSString.stringWithUTF8String(self.chat_buffer)))
      @chat_window_text.checkTextInDocument nil
      @chat_window_text.setEditable false
    end
  end

  def sign_on
    begin
      @ts = TCPSocket.open(@host, @port)
    rescue
      log("Could not connect to the GlobalChat server. Will rety in 5 seconds.\n")
      #sleep 5
      return false
    end
    @last_ping = Time.now # fake ping
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
    $autoreconnect = true
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
        loop do
          sleep 5
          if sign_on
            break
          end
        end
      end
    end
  end

  def return_to_server_list
    $autoreconnect = false
    sign_out
    run_on_main_thread do
      self.server_list_window.makeKeyAndOrderFront(nil)
      self.chat_window.orderOut(self)
      cleanup
      $connected = false
    end
  end

  def show_chat
    run_on_main_thread do
      @server_list_window.orderOut(self)
      @chat_window.makeKeyAndOrderFront(nil)
      if @server_name
        log "Connected to #{@server_name} \n"
        @chat_window.setTitle @server_name
      end
    end
  end

  def update_and_scroll
    parse_links
    update_chat_views
  end

  def begin_async_read_queue
    @queue.async do
      loop do
        sleep 0.1
        data = ""
        begin
          while line = @ts.recv(1)
            raise if @last_ping < Time.now - 30
            break if line == "\0"
            data += line
          end
        rescue
          autoreconnect
          break
        end

        # everything must become unicode!
        data = NSString.stringWithUTF8String(data)
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
      show_chat
      get_log
      get_handles
      $connected = true
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n")
      nicks_table.reloadData
    elsif command == "PONG"
      @nicks = parr.last.split("\n")
      @nicks_table.reloadData
      ping
    elsif command == "BUFFER"
      buffer = parr[1]
      unless buffer == "" || buffer == nil
        @chat_buffer = buffer
        update_and_scroll
      end
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      output_to_chat_window("#{handle} has entered\n")
      @nicks << handle
      @nicks.uniq!
      @nicks_table.reloadData
    elsif command == "LEAVE"
      handle = parr[1]
      output_to_chat_window("#{handle} has exited\n")
      @nicks.delete(handle)
      @nicks_table.reloadData
    elsif command == "ALERT"
      text = parr[1]
      alert(text)
      # i looze
      return_to_server_list
    end
  end

  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send @ts, msg
  end

  def sock_send io, msg
    begin
      # send unicode only !
      msg = NSString.stringWithUTF8String(msg)
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

  def check_if_pinged(handle, message)
    if @handle != handle && message.include?(@handle)
      NSBeep()
      Notification.send(handle, message)
      NSApp.requestUserAttention 0
      @msg_count ||= 0
      @msg_count += 1
      NSApplication.sharedApplication.dockTile.setBadgeLabel(@msg_count.to_s)
    end
  end

  def check_if_away_or_back(handle, message)
    if message.include?("brb")
      @away_nicks << handle
    elsif message.include?("back")
      @away_nicks.delete(handle)
    end
  end

  def add_msg(handle, message)
    check_if_pinged(handle, message)
    check_if_away_or_back(handle, message)
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
    #@queue.async do
    @last_ping = Time.now
    send_message("PING", [@chat_token])
    #end
  end

  def p obj
    NSLog obj.description
  end

  def log str
    #NSLog str
    output_to_chat_window(str)
  end

  def output_to_chat_window str
    @chat_buffer += "#{str}"
    update_and_scroll
  end

end
