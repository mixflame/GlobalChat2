#!/usr/bin/env ruby

require 'uri'
require 'socket'

class GlobalChatController

  

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :handle_text_field, :connect_button, :server_list_window, :chat_window, :chat_window_text, :chat_message, :nicks_table, :application, :scroll_view, :last_scroll_view_height, :host, :port, :password, :ts


  def initialize
    
  end

  def quit
    sign_out
  end

  def sendMessage(message)
    if message != ""
      post_message(message)
    end
  end

  def sign_on
    log "Connecting to: #{@host} #{@port}"
    @ts = TCPSocket.open(@host, @port)
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
  end
  
  def begin_async_read_queue
    Thread.new do
      loop do
        data = ""
        while line = @ts.recv(1)
          break if line == "\0" 
          data += line
        end
        unless data == ""
          # log data
          parse_line(data)
        end
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
      output_to_chat_window @nicks.inspect
    elsif command == "BUFFER"
      buffer = parr[1]
      unless buffer.nil?
        output_to_chat_window buffer
      end
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    elsif command == "JOIN"
      handle = parr[1]
      self.nicks << handle
      output_to_chat_window "#{handle} has entered\n"
    elsif command == "LEAVE"
      handle = parr[1]
      output_to_chat_window "#{handle} has exited\n"
      self.nicks.delete(handle)
    end
  end
  
  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send @ts, msg
  end
  
  def sock_send io, msg
    msg = "#{msg}\0"
    log msg
    io.send msg, 0
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    add_msg(self.handle, message)
  end
  
  def add_msg(handle, message)
    msg = "#{handle}: #{message}\n"
    output_to_chat_window msg
    #self.chat_buffer += msg
  end

  def output_to_chat_window str
    puts str
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
  
  def log(msg)
    #NSLog(msg)
    #output_to_chat_window msg
  end

end


#output_to_chat_window 'enter name'
#name = gets
#output_to_chat_window 'enter server'
#server = gets

gcc = GlobalChatController.new
gcc.handle = "jsilver-console" #name.strip
gcc.host = "mdks.org" #server.strip
gcc.port = 9994
gcc.password = ""
gcc.nicks = []
gcc.chat_buffer = ""
gcc.sign_on

at_exit do
  gcc.quit
end

while message = gets
  message = message.chop
  if message == "/quit"
    break
  else
    gcc.sendMessage(message)
  end

  
end

