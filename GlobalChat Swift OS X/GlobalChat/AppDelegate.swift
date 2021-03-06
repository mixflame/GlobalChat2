//
//  AppDelegate.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/1/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var slc: ServerListController!
    @IBOutlet weak var gcc: GlobalChatController!
    @IBOutlet weak var ver_menu_item: NSMenuItem!
    @IBOutlet weak var tos: NSWindow!
    
    var connected = false
    
    
    @IBAction func acceptTos(sender: Any) {
        tos.orderOut(sender)
        slc.server_list_window.makeKeyAndOrderFront(sender)
        let prefs = UserDefaults.standard
        prefs.set(true, forKey: "accepted")
    }
    
    @IBAction func declineTos(sender: Any) {
        NSApplication.shared.terminate(self)
    }


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let prefs = UserDefaults.standard
        slc.handle.stringValue = (prefs.string(forKey: "handle") ?? "")
        slc.host.stringValue = (prefs.string(forKey: "host") ?? "")
        slc.port.stringValue = (prefs.string(forKey: "port") ?? "")
        
        let accepted : Bool = (prefs.bool(forKey: "accepted"))
        
        if accepted {
            acceptTos(sender: self)
        }
        
        slc.server_list_table.target = slc
        let selector : Selector = #selector(ServerListController.connect(_:))
        slc.server_list_table.doubleAction = selector
        

        let infoDict = Bundle.main.infoDictionary
        let versionNum : String = infoDict!["CFBundleShortVersionString"] as! String
        let build : String = infoDict!["CFBundleVersion"] as! String
        
        ver_menu_item.title = "v\(versionNum) build \(build)"
        
        connected = false
        
        slc.get_servers()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidBecomeActive(_ a_notification: Notification) {
        NSApplication.shared.dockTile.badgeLabel = nil
        self.gcc.msg_count = 0
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApplication.shared.terminate(self)
        return true
    }


}

