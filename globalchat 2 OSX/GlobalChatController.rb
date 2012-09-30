require 'uri'
require 'socket'

class GlobalChatController

  

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :handle_text_field, :connect_button, :server_list_window, :chat_window, :chat_window_text, :chat_message, :nicks_table, :application, :scroll_view, :last_scroll_view_height, :host, :port, :password, :ts


  def initialize
    #@mutex = Mutex.new
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
      @last_buffer = self.chat_buffer
    
  end

  def sign_on
    NSLog "Connecting to: #{@host} #{@port}"
    @ts = TCPSocket.open(@host, @port)
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
    NSTimer.scheduledTimerWithTimeInterval(0.1,
                                           target:self,
                                           selector:"update_and_scroll",
                                           userInfo:nil,
                                           repeats:true)
  end
  
  def update_and_scroll
      if self.chat_buffer != @last_buffer
        update_chat_views
      end
    
      scroll_the_scroll_view_down
    
  end
  
  def begin_async_read_queue
    @queue.async do
      while line = @ts.gets   # Read lines from the socket
        line = line.chop
        parse_line(line)
      end
    end
  end
  
  def parse_line(line)
    parr = line.split("::!!::")
    NSLog line
    command = parr.first
    if command == "TOKEN"
      self.chat_token = parr.last
      get_handles
      get_log
    elsif command == "HANDLE"
      self.nicks << parr.last
      @nicks_table.dataSource = self
      @nicks_table.reloadData
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    end
  end
  
  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    NSLog msg
    @ts.puts msg
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(self.handle, message)
  end
  
  def add_msg(handle, message)
    msg = "#{handle}: #{message}\n"
    NSLog msg
    self.chat_buffer += msg
  end

  def get_log
    send_message "GETBUFFER", [@chat_token]
  end

  def get_handles
    send_message "GETHANDLES", [@chat_token]
  end

  def sign_out
    send_message "SIGNOFF", [@chat_token]
  end

end
