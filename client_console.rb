#!/usr/bin/env ruby

require 'uri'
require 'socket'

class GlobalChatController

  

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :handle_text_field, :connect_button, :server_list_window, :chat_window, :chat_window_text, :chat_message, :nicks_table, :application, :scroll_view, :last_scroll_view_height, :host, :port, :password, :ts


  def initialize
    
  end


  # hook on exit.. same as nexus
  def quit
    sign_out
    
  end

  def sendMessage(message)
    if message != ""
      post_message(message)
    end
  end

  def sign_on
    puts "Connecting to: #{@host} #{@port}"
    @ts = TCPSocket.open(@host, @port)
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
  end
  
  def begin_async_read_queue
    Thread.new do
      while line = @ts.gets   # Read lines from the socket
        line = line.chop
        parse_line(line)
      end
    end
  end
  
  def parse_line(line)
    parr = line.split("::!!::")
    #puts line
    command = parr.first
    if command == "TOKEN"
      self.chat_token = parr.last
      get_handles
      get_log
    elsif command == "HANDLE"
      self.nicks << parr.last
    elsif command == "SAY"
      handle = parr[1]
      msg = parr[2]
      add_msg(handle, msg)
    end
  end
  
  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    #puts msg
    @ts.puts msg
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    # cant disable gets saying so Ill disable local re-saying
    #add_msg(self.handle, message)
  end
  
  def add_msg(handle, message)
    msg = "#{handle}: #{message}\n"
    puts msg
    #self.chat_buffer += msg
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

gcc = GlobalChatController.new
gcc.handle = "jsilver2"
gcc.host = "localhost"
gcc.port = 9994
gcc.password = ""
gcc.nicks = []
gcc.chat_buffer = ""
gcc.sign_on


while message = gets
  message = message.chop
  if message == "/quit"
    break
  else
    gcc.sendMessage(message)
  end

  
end

