require 'rubygems'
require 'Qt4'
require 'qtuitools'
require 'net/http'
require 'socket'
require 'thread'
# require 'qt_thread'
require 'pry'
require 'pstore'
require './global_chat_controller.rb'
require './server_list.rb'
require './global_chat.rb'

app = Qt::Application.new ARGV
# Qt.debug_level = Qt::DebugLevel::High
sl = ServerList.new
sl.show
app.exec