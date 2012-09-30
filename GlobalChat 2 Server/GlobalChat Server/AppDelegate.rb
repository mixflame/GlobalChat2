

class AppDelegate
    attr_accessor :window, :gcsc

    def applicationDidFinishLaunching(a_notification)
      # entry
      @gcsc.gchatserv = GlobalChatServer.new
      
      @gcsc.gchatserv.start
      
      @gcsc.published = false
      
      NSTimer.scheduledTimerWithTimeInterval(1,
        target:@gcsc,
        selector:"checkStatus",
        userInfo:nil,
        repeats:true)
      
      
    end
end

