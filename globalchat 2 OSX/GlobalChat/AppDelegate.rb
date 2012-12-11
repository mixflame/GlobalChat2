class AppDelegate

  attr_accessor :window, :slc, :gcc, :ver_menu_item

  def applicationDidFinishLaunching(a_notification)

    $prefs = NSUserDefaults.standardUserDefaults
    @slc.handle.setStringValue($prefs.stringForKey("handle") || "")
    @slc.host.setStringValue($prefs.stringForKey("host") || "")
    @slc.port.setStringValue($prefs.stringForKey("port") || "")

    @slc.server_list_table.target = @slc
    @slc.server_list_table.doubleAction = 'connect:'

    infoDict = NSBundle.mainBundle.infoDictionary
    versionNum = infoDict.objectForKey "CFBundleShortVersionString"
    build = infoDict.objectForKey "CFBundleVersion"

    ver_menu_item.setTitle "v#{versionNum} build #{build}"

    $connected = false


  end


  def applicationDidBecomeActive(a_notification)
    NSApplication.sharedApplication.dockTile.setBadgeLabel(nil)
    self.gcc.msg_count = 0
  end

end

