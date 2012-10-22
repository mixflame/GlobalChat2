require 'net/http'

class ServerListController

    attr_accessor :server_list_hash, :names, :server_list_table, :server_list_window, :gcc, :chat_window, :host, :port, :password, :handle

  def initialize
  	get_servers
  end

  def get_servers
    @server_list_hash = Net::HTTP.get('nexusnet.herokuapp.com', '/msl').
    split("\n").
    collect do |s|
      par = s.split("-!!!-")
      {:host => par[1], :name => par[0], :port => par[2]}
    end

    @names = Net::HTTP.get('nexusnet.herokuapp.com', '/msl').
    split("\n").
    collect do |s|
      s.split("-!!!-")[0]
    end
    
  end

  def tableView(view, objectValueForTableColumn:column, row:index)
    self.names[index]
  end

  def numberOfRowsInTableView(view)
    self.names.size
  end


  def refresh(sender)
  	get_servers
    @server_list_table.reloadData
  end
  
  def changeInfo(sender)
    @host.setStringValue @server_list_hash[sender.selectedRow][:host]
    @port.setStringValue @server_list_hash[sender.selectedRow][:port]
  end

  def connect(sender)
      # save defaults
      $prefs.setObject(@host.stringValue, :forKey => "host")
      $prefs.setObject(@handle.stringValue, :forKey => "handle")
      $prefs.setObject(@port.stringValue, :forKey => "port")
    
      @gcc.handle = @handle.stringValue
      @gcc.host = @host.stringValue
      @gcc.port = @port.stringValue
      @gcc.password = @password.stringValue
      @gcc.nicks = []
      @gcc.chat_buffer = ""
      
      if @gcc.sign_on
        #self.server_list_window.close
        self.chat_window.makeKeyAndOrderFront(nil)
      end 
  end


end
