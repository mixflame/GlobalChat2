class AppDelegate
  attr_accessor :window

  def application(application, didFinishLaunchingWithOptions:launchOptions)
      $prefs = NSUserDefaults.standardUserDefaults
      $term = AsyncSocket.ZeroData
      true
  end

  def applicationWillResignActive(application)
    $gcc.sign_out
  end
  
end
