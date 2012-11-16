class AppDelegate

    attr_accessor :window, :slc, :gcc
  
    def applicationDidFinishLaunching(a_notification)
      $window = window
      $prefs = NSUserDefaults.standardUserDefaults
      @slc.handle.setStringValue($prefs.stringForKey("handle") || "")
      @slc.host.setStringValue($prefs.stringForKey("host") || "")
      @slc.port.setStringValue($prefs.stringForKey("port") || "")
      
      
    end
    

end

