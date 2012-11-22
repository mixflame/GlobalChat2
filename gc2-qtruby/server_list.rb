class ServerList < Qt::Widget

  signals :updateTitle

  def initialize(parent=nil)
    super parent
    loader = Qt::UiLoader.new
    file = Qt::File.new 'ServerList.ui' do
      open Qt::File::ReadOnly
    end
    window = loader.load file
    file.close

    @pstore = PStore.new("gchat2pro.pstore")

    @sl = window.findChild(Qt::ListWidget, "listWidget")
    @handle = window.findChild(Qt::LineEdit, "lineEdit")
    @host = window.findChild(Qt::LineEdit, "lineEdit_2")
    @port = window.findChild(Qt::LineEdit, "lineEdit_3")
    @password = window.findChild(Qt::LineEdit, "lineEdit_4")
    @refresh = window.findChild(Qt::PushButton, "pushButton")
    @connect = window.findChild(Qt::PushButton, "pushButton_2")

    @sl.connect(SIGNAL "currentTextChanged(const QString&)") { |item| get_info(item) }
    @refresh.connect(SIGNAL :clicked) { refresh }
    @connect.connect(SIGNAL :clicked) { connect }

    self.layout = Qt::VBoxLayout.new do |l|
      l.addWidget(window)
    end

    self.windowTitle = tr("Server List")

    get_servers

    load_prefs
  end

  def refresh
    @sl.clear
    get_servers
  end

  def load_prefs
    @pstore.transaction do
      @handle.text = @pstore["handle"] || ""
      @host.text = @pstore["host"] || ""
      @port.text = @pstore["port"] || ""
    end
  end

  def save_prefs
    @pstore.transaction do
      @pstore["handle"] = @handle.text
      @pstore["host"] = @host.text
      @pstore["port"] = @port.text
    end
  end

  def get_info(name)
    if name != "" && name != nil
      row = @names.index(name)
      @host.text = @server_list_hash[row][:host]
      @port.text = @server_list_hash[row][:port]
    end
  end


  def get_servers

    Thread.new do
      @server_list_hash = Net::HTTP.get('nexusnet.herokuapp.com', '/msl').
      split("\n").
      collect do |s|
        par = s.split("-!!!-")
        {:host => par[1], :name => par[0], :port => par[2]}
      end


      @names = @server_list_hash.map { |i| i[:name] }

      update_servers
    end

  end

  def update_servers
    @names.each do |name|
      @sl.add_item(name)
    end
  end


  def connect
    # save defaults
    save_prefs
    self.hide
    gc = GlobalChat.new(@handle.text, @host.text, @port.text, @password.text)
    gc.show
  end

end
