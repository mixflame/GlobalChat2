class AppDelegate
  attr_accessor :window

  def application(application, didFinishLaunchingWithOptions:launchOptions)
      $prefs = NSUserDefaults.standardUserDefaults
      $term = AsyncSocket.LFData # main bug of this app FIXME
      true
  end

  def applicationWillResignActive(application)
    $gcc.sign_out
  end
  
end
