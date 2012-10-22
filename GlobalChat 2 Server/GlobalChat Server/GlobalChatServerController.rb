require 'net/http'


# just a delegate to the GServer
class GlobalChatServerController

  attr_accessor :gchatserv, :application

  attr_accessor :server_name, :password, :server_status, :publicize_button, :privatize_button, :scrollback_mode, :published, :host

  $queue = Dispatch::Queue.new('com.mdx.globalchat')
  $mutex = Mutex.new

  def checkStatus # change server setting
    if @gchatserv.stopped?
      @server_status.setStringValue("Stopped")
    else
      @server_status.setStringValue("Running Scrollback:#{@scrollback_mode.state==1} Published:#{@published}")
      @gchatserv.password = @password.stringValue
      @gchatserv.scrollback = (@scrollback_mode.state==1)
      @publicize_button.setEnabled (@host.stringValue != "" && @server_name.stringValue != "" && @published == false)
      @privatize_button.setEnabled (@host.stringValue != "" && @server_name.stringValue != "" && @published == true)
    end
  end

  def quit(sender)
    if @server_name.stringValue != "" && @published == true
        unpingNexus(sender)
    end
    @application.terminate(self)
  end
  
  def unpingNexus(sender)
    $queue.async do
      nexus_offline
    end
  end


  def pingNexus(sender)
    $queue.async do
      ping_nexus
    end
  end

  def ping_nexus
    NSLog "Pinging NexusNet that I'm Online!!"
    host = @host.stringValue
    chatnet_name = @server_name.stringValue
    port = 9994
    uri = URI.parse("http://nexusnet.herokuapp.com/online")
    query = {:name => chatnet_name, :port => port, :host => host}
    uri.query = URI.encode_www_form( query )
    Net::HTTP.get(uri)
    @published = true
  end

  def nexus_offline
    NSLog "Informing NexusNet that I have exited!!!"
    Net::HTTP.get_print("nexusnet.herokuapp.com", "/offline")
    @published = false
  end


end