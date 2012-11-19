class GlobalChatController < UIViewController
  extend IB

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :last_scroll_view_height, :host, :port, :password, :ts, :times, :disconnect_timer, :scroll_timer, :old_frame

  outlet :chat_window_text
  outlet :nicks_table
  outlet :scroll_view
  outlet :chat_message

  # message field moving

  def textFieldDidBeginEditing(textfield)
    UIView.beginAnimations(nil, context:nil)
    UIView.setAnimationDelegate(self)
    UIView.setAnimationDuration(0.5)
    UIView.setAnimationBeginsFromCurrentState(true)
    @old_frame = chat_message.frame
    offset = Device.ipad? ? 0 : 30
    chat_message.frame = CGRectMake(chat_message.frame.origin.x, ((chat_message.frame.origin.y / 2) - offset), chat_message.frame.size.width, chat_message.frame.size.height)
    self.view.bringSubviewToFront chat_message
    UIView.commitAnimations
  end

  def textFieldDidEndEditing(textfield)
    UIView.beginAnimations(nil, context:nil)
    UIView.setAnimationDelegate(self)
    UIView.setAnimationDuration(0.5)
    UIView.setAnimationBeginsFromCurrentState(true)
    chat_message.frame = @old_frame
    UIView.commitAnimations
  end

  def touchesBegan(touches, withEvent:event)
    chat_message.resignFirstResponder
  end

  # orientation

  def preferredInterfaceOrientationForPresentation
    UIDeviceOrientationLandscapeRight
  end


  def supportedInterfaceOrientations
    UIInterfaceOrientationMaskLandscapeRight | UIInterfaceOrientationMaskLandscapeLeft
  end

  def shouldAutorotate
    true
  end

  def viewDidAppear(animated)
    super(animated)
    # self.attemptRotationToDeviceOrientation
  end

  def shouldAutorotateToInterfaceOrientation(interfaceOrientation)
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight) || (interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
  end


  def foghornMe(indexPath)
    chat_message.setText("#{@nicks[indexPath.row]}: ")
    select_chat_text
  end

  def select_chat_text
    chat_message.becomeFirstResponder
    chat_message.resignFirstResponder
    #chat_message.currentEditor.setSelectedRange(NSRange.new(@chat_message.text.length,0))
  end

  def run_on_main_thread &block
    block.performSelectorOnMainThread "call:", withObject:nil, waitUntilDone:false
  end

  def textFieldShouldReturn(textField)
    send_the_chat_message
    textField.resignFirstResponder
  end

  def viewWillAppear(animated)
    super(animated)
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

  def tableView(tableView, didSelectRowAtIndexPath:indexPath)
    foghornMe(indexPath)
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

    return if (@host == "" || @port == "")

    @ts = AsyncSocket.alloc.initWithDelegate(self, delegateQueue:Dispatch::Queue.main)
    @ts.connectToHost(@host, onPort:@port, error:nil)
  end

  def update_and_scroll
    if @chat_buffer != @last_buffer
      update_chat_views
    end
    scroll_the_scroll_view_down
  end

  def parse_line(line)
    parr = line.split("::!!::")
    #p parr
    command = parr.first
    if command == "TOKEN"
      @chat_token = parr[1]
      @handle = parr[2]
      @server_name = parr[3]
      output_to_chat_window "Connected to #{@server_name} \n"
      ping
      get_handles
      get_log
      $connected = true
    elsif command == "PONG"
      @nicks = parr.last.split("\n")
      nicks_table.reloadData
      ping
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n")
      nicks_table.reloadData
    elsif command == "BUFFER"
      buffer = parr[1]
      unless buffer.nil?
        @chat_buffer = buffer
        update_and_scroll
      end
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      @nicks << handle
      output_to_chat_window("#{handle} has entered")
    elsif command == "LEAVE"
      handle = parr[1]
      output_to_chat_window("#{handle} has exited")
    elsif command == "ALERT"
      $autoreconnect = false
      text = parr[1]
      log("#{text}\n") do
        return_to_server_list
      end
    end
  end

  def output_to_chat_window str
    @chat_buffer += "#{str}\n"
    update_and_scroll
  end

  def onSocket(sock, didConnectToHost:host, port:port)
    $autoreconnect = true
    $connected = true
    $app.switch_to_vc($gcc)
    @last_ping = Time.now # fake ping
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    read_line
  end

  def onSocket(sock, didReadData:data, withTag:tag)
    line = NSString.stringWithUTF8String(data.bytes)
    p line
    parse_line(line)
    read_line
  end

  def onSocketDidDisconnect(sock)
    $connected = false
    autoreconnect
  end

  def return_to_server_list
    #run_on_main_thread do
    $autoreconnect = false
    @ts.disconnect
    $app.switch_to_vc($slc)
    #end
  end

  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::") + "\0"
    # p msg
    data = msg.dataUsingEncoding(NSUTF8StringEncoding)
    begin
      @ts.writeData(data, withTimeout:-1, tag: 0)
    rescue
      autoreconnect
    end
  end

  def read_line
    begin
      @ts.readDataToData($term, withTimeout:-1, tag:0)
    rescue
      autoreconnect
    end
    autoreconnect if @last_ping < Time.now - 30
  end

  def autoreconnect
    $queue.async do
      unless $autoreconnect == false
        loop do
          break if $connected == true
          run_on_main_thread do
            output_to_chat_window("Could not connect to GlobalChat. Will retry in 5 seconds..")
            NSLog "connected? #{$connected}"

            sign_on
          end

          sleep 5



        end
      end
    end
  end


  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(@handle, message)
  end

  def add_msg(handle, message)
    if @handle != handle && message.include?(@handle)
      local_file = NSURL.fileURLWithPath(File.join(NSBundle.mainBundle.resourcePath, 'ding.wav'))
      BW::Media.play(local_file) do
        #no-op.. just play sound
      end
      @msg_count ||= 0
      @msg_count += 1
    end
    msg = "#{handle}: #{message}"
    output_to_chat_window(msg)
  end

  def get_log
    @chat_buffer = ""
    send_message "GETBUFFER", [@chat_token]
  end

  def get_handles
    @nicks = []
    send_message "GETHANDLES", [@chat_token]
  end

  def ping
    # sleep 3
    @last_ping = Time.now
    send_message("PING", [@chat_token])
  end

  def log str, &block
    # NSLog str
    # output_to_chat_window(str)
    UIAlertView.alert(str) do block.call end
  end

end