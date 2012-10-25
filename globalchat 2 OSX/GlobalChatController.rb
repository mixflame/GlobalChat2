require 'uri'
require 'socket'

class GlobalChatController

  

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :handle_text_field, :connect_button, :server_list_window, :chat_window, :chat_window_text, :chat_message, :nicks_table, :application, :scroll_view, :last_scroll_view_height, :host, :port, :password, :ts


  def initialize
    @mutex = Mutex.new
    @queue = Dispatch::Queue.new('com.jonsoft.globalchat')
  end

  def quit(sender)
    sign_out
    @application.terminate(self)
  end

  def tableView(view, objectValueForTableColumn:column, row:index)
    self.nicks[index]
  end

  def numberOfRowsInTableView(view)
    self.nicks.size
  end

  def sendMessage(sender)
    @message = sender.stringValue
    if @message != ""
      post_message(@message)
      @chat_message.setStringValue('')
    end
  end

  def scroll_the_scroll_view_down
    y = self.scroll_view.documentView.frame.size.height - self.scroll_view.contentSize.height
    self.scroll_view.contentView.scrollToPoint(NSMakePoint(0, y))
  end

  def update_chat_views
    @chat_window_text.setString(NSString.stringWithUTF8String(self.chat_buffer))
  end

  def sign_on
    #log "Connecting to: #{@host} #{@port}"
    begin
      @ts = TCPSocket.open(@host, @port)
    rescue
      alert = NSAlert.new
      alert.setMessageText("Could not connect to GlobalChat server.")
      alert.runModal
      return false
    end
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
    true
  end
  
  def return_to_server_list
    @mutex.synchronize do
      alert = NSAlert.new
      alert.setMessageText("GlobalChat connection crashed.")
      alert.runModal
      self.server_list_window.makeKeyAndOrderFront(nil)
      self.chat_window.orderOut(self)
    end
  end
  
  def update_and_scroll
    update_chat_views
    scroll_the_scroll_view_down
  end
  
  def begin_async_read_queue
    @queue.async do
      loop do
        sleep 0.1
        data = ""
        begin
          while line = @ts.recv(1)
            break if line == "\0" 
            data += line
          end
        rescue
          return_to_server_list
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
      get_handles
      get_log
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n")
      @nicks_table.dataSource = self
      @nicks_table.reloadData
    elsif command == "BUFFER"
      buffer = parr[1]
      #unless buffer == "" || buffer == nil
      output_to_chat_window(buffer)
      #end
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      self.nicks << handle
      output_to_chat_window("#{handle} has entered\n")
      @nicks_table.dataSource = self
      @nicks_table.reloadData
    elsif command == "LEAVE"
      handle = parr[1]
      output_to_chat_window("#{handle} has exited\n")
      self.nicks.delete(handle)
      @nicks_table.dataSource = self
      @nicks_table.reloadData
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
      return_to_server_list
    end
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(self.handle, message)
  end
  
  def add_msg(handle, message)
    if @handle != handle && message.include?(@handle)
      NSBeep()
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
  
  def p obj
    NSLog obj.description
  end
  
  def log str
    # NSLog str
    output_to_chat_window(str)
  end
  
  def output_to_chat_window str
    @mutex.synchronize do
      @chat_buffer += "#{str}"
      update_and_scroll
    end
  end

end
