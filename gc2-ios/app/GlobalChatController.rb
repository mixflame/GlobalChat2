class GlobalChatController < UIViewController
  extend IB

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :last_scroll_view_height, :host, :port, :password, :ts

  outlet :chat_window_text
  outlet :nicks_table
  outlet :scroll_view
  outlet :chat_message

  def textFieldShouldReturn(textField)
    send_the_chat_message
    textField.resignFirstResponder
  end

  def viewDidLoad
    $gcc = self
    @mutex = Mutex.new
    sign_on
  end

  def tableView(tableView, cellForRowAtIndexPath:indexPath)
    cell = tableView.dequeueReusableCellWithIdentifier("GlobalChat2")
    if not cell
      cell = UITableViewCell.alloc.initWithStyle UITableViewCellStyleDefault, reuseIdentifier:'GlobalChat2'
    end
    cell.setText @nicks[indexPath.row]
    cell
  end

  def tableView(tableView, numberOfRowsInSection: section)
    @nicks.nil? ? 0 : @nicks.size
  end

  def send_the_chat_message
    message = @chat_message.text
    if message != ""
      post_message(message)
      @chat_message.text = ''
    end
    # update_and_scroll
  end

  def scroll_the_scroll_view_down
    y = @chat_window_text.contentSize.height - @chat_window_text.frame.size.height
    if @last_scroll_view_height != y
      @chat_window_text.contentOffset = CGPoint.new(0, y);
      @last_scroll_view_height = y
    end
  end

  def update_chat_views
    chat_window_text.text = NSString.stringWithUTF8String(@chat_buffer)
    @last_buffer = @chat_buffer
  end

  def sign_on
    @ts = AsyncSocket.alloc.initWithDelegate(self, delegateQueue:Dispatch::Queue.main)
    @ts.connectToHost(@host, onPort:@port, error:nil)
    NSTimer.scheduledTimerWithTimeInterval(0.1,
                                           target:self,
                                           selector:"update_and_scroll",
                                           userInfo:nil,
                                           repeats:true)
  end

  def update_and_scroll
    if @chat_buffer != @last_buffer
      update_chat_views
    end
    scroll_the_scroll_view_down
  end

  def parse_line(line)
    parr = line.split("::!!::")
    p parr
    command = parr.first
    if command == "TOKEN"
      @chat_token = parr.last
      get_handles
      sleep 1
      get_log
    elsif command == "HANDLE"
      @nicks << parr.last
      # @nicks.uniq!
      nicks_table.reloadData
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      @nicks << handle
      @chat_buffer += "#{handle} has entered\n"
      nicks_table.dataSource = self
      nicks_table.reloadData
    elsif command == "LEAVE"
      handle = parr[1]
      @chat_buffer += "#{handle} has exited\n"
      @nicks.delete(handle)
      nicks_table.reloadData
    end
  end

  def onSocket(sock, didConnectToHost:host, port:port)
    puts "connected #{host}:#{port}"
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    read_line
  end

  def onSocket(sock, didReadData:data, withTag:tag)
    line = NSString.stringWithUTF8String(data.bytes)
    line = line.strip
    parse_line(line)
    read_line
  end

  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    data = "#{msg}\n".dataUsingEncoding(NSUTF8StringEncoding)
    @ts.writeData(data, withTimeout:5, tag: 0)
  end

  def read_line
    @ts.readDataToData($term, withTimeout:5, tag:0)
  end
  

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(@handle, message)
  end

  def add_msg(handle, message)
    msg = "#{handle}: #{message}\n"
    @chat_buffer += msg
  end

  def get_log
    @chat_buffer = ""
    send_message "GETBUFFER", [@chat_token]
  end

  def get_handles
    @nicks = []
    send_message "GETHANDLES", [@chat_token]
  end

  def sign_out
    send_message "SIGNOFF", [@chat_token]
    self.performSegueWithIdentifier("Back2Login", sender:self)
  end

end