class AppDelegate

    attr_accessor :window, :slc, :gcc
  
    def applicationDidFinishLaunching(a_notification)
    
    
      $prefs = NSUserDefaults.standardUserDefaults
      @slc.handle.setStringValue($prefs.stringForKey("handle") || "")
      @slc.host.setStringValue($prefs.stringForKey("host") || "")
      @slc.port.setStringValue($prefs.stringForKey("port") || "")
      
      $connected = false
      
      
    end
  
  
    def applicationDidBecomeActive(a_notification)
      NSApplication.sharedApplication.dockTile.setBadgeLabel(nil)
      self.gcc.msg_count = 0
    end

end

