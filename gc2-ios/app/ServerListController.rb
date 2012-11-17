class ServerListController < UIViewController
  extend IB
  include BubbleWrap

  attr_accessor :server_list_hash, :names

  outlet :names
  outlet :server_list_table
  outlet :host, UITextField
  outlet :port, UITextField
  outlet :password, UITextField
  outlet :handle

  def preferredInterfaceOrientationForPresentation
    UIInterfaceOrientationMaskPortrait
  end


  def supportedInterfaceOrientations
    UIInterfaceOrientationMaskPortrait
  end

  def shouldAutorotate
    false
  end

  def shouldAutorotateToInterfaceOrientation(interface)
    return interface == UIInterfaceOrientationMaskPortrait
  end

  def textFieldShouldReturn(textField)
    textField.resignFirstResponder
  end

  def load_prefs
    handle.text = $prefs.stringForKey("handle") || ""
    host.text = $prefs.stringForKey("host") || ""
    port.text = $prefs.stringForKey("port") || ""
  end

  def viewWillAppear(animated)
    $slc = self
    $nav = self.parentViewController
    $autoreconnect = false
    load_prefs
    get_servers
    super(animated)
  end


  def get_servers
    HTTP.get('http://nexusnet.herokuapp.com/msl') do |resp|
      break if resp.body.nil?
      @server_list_hash = resp.body.to_str.
      split("\n").
      collect do |s|
        par = s.split("-!!!-")
        {:host => par[1], :name => par[0], :port => par[2]}
      end
      @names = @server_list_hash.collect do |s|
        s[:name]
      end
      @server_list_table.reloadData
    end
  end

  def tableView(tableView, cellForRowAtIndexPath:indexPath)
    cell = tableView.dequeueReusableCellWithIdentifier("GlobalChat2")

    if not cell
      cell = UITableViewCell.alloc.initWithStyle UITableViewCellStyleDefault, reuseIdentifier:'GlobalChat2'
    end

    cell.setText @names[indexPath.row]

    cell
  end

  def tableView(tableView, numberOfRowsInSection: section)
    @names.nil? ? 0 : @names.size
  end

  def tableView(tableView, didSelectRowAtIndexPath:indexPath)
    # p @server_list_hash[indexPath.row]
    host.text = @server_list_hash[indexPath.row][:host]
    port.text = @server_list_hash[indexPath.row][:port]
  end

  def refresh(sender)
    get_servers
  end

  def connect(sender)
    # save defaults
    $prefs.setObject(host.text, :forKey => "host")
    $prefs.setObject(handle.text, :forKey => "handle")
    $prefs.setObject(port.text, :forKey => "port")

    $gcc = $app.load_vc("ChatWindow")
    $gcc.handle = handle.text
    $gcc.host = host.text
    $gcc.port = port.text
    $gcc.password = password.text
    $gcc.chat_buffer = ""
    $gcc.nicks = []
    $gcc.ts = nil
    $gcc.times = 0
    $gcc.sign_on

  end


end