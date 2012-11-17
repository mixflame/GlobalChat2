#!/usr/bin/env ruby

require 'uri'
require 'socket'

class GlobalChatController

  attr_accessor :chat_token, :chat_buffer, :nicks, :handle, :handle_text_field, :connect_button, :server_list_window, :chat_window, :chat_window_text, :chat_message, :nicks_table, :application, :scroll_view, :last_scroll_view_height, :host, :port, :password, :ts, :msg_count

  def initialize
    @sent_messages = []
    @sent_msg_index = 0
  end

  def sendMessage(message)
    begin
      if message != ""
        post_message(message)
      end
    rescue
      autoreconnect
    end
  end

  def sign_on
    begin
      @ts = TCPSocket.open(@host, @port)
    rescue
      log("Could not connect to GlobalChat server. Will retry in 5 seconds.")
      sleep 5
      return false
    end
    sign_on_array = @password == "" ? [@handle] : [@handle, @password]
    send_message("SIGNON", sign_on_array)
    begin_async_read_queue
    $autoreconnect = true
    true
  end

  def autoreconnect
    unless $autoreconnect == false
      loop do
        if start_client
          break
        end
      end
    end
  end

  def begin_async_read_queue
    Thread.new do
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
        #p data
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
      log "Connected to #{@server_name} \n"
      ping
      get_handles
      get_log
      $connected = true
    elsif command == "PONG"
      @nicks = parr.last.split("\n")
      ping
    elsif command == "HANDLES"
      @nicks = parr.last.split("\n")
      output_to_chat_window @nicks.inspect
    elsif command == "BUFFER"
      buffer = parr[1]
      unless buffer == "" || buffer == nil
        output_to_chat_window(buffer)
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
      log("#{text}\n")

      exit
      # @ts.close
    end
  end

  def send_message(opcode, args)
    msg = opcode + "::!!::" + args.join("::!!::")
    sock_send @ts, msg
  end

  def sock_send io, msg
    begin
      #p msg
      msg = "#{msg}\0"
      io.send msg, 0
    rescue
      autoreconnect
    end
  end

  def post_message(message)
    send_message "MESSAGE", [message, @chat_token]
    #add_msg(self.handle, message)
  end

  def add_msg(handle, message)
    if @handle != handle && message.include?(@handle)
      print "\a"
      @msg_count ||= 0
      @msg_count += 1
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
    sleep 3
    # @last_ping = Time.now
    send_message("PING", [@chat_token])
  end

  def log str
    output_to_chat_window(str)
  end

  def output_to_chat_window str
    puts str
  end


end


puts 'enter handle'
$name = gets
puts 'enter server'
$server = gets

def start_client
  `clear`
  gcc = GlobalChatController.new
  gcc.handle = $name.strip || "jsilver-console"
  gcc.host = $server.strip || "localhost"
  gcc.port = 9994
  gcc.password = ""
  gcc.nicks = []
  gcc.chat_buffer = ""
  gcc.autoreconnect if gcc.sign_on == false


  while message = gets
    message = message.chop
    if message == "/quit"
      break
    else
      gcc.sendMessage(message)
    end
  end
end


start_client