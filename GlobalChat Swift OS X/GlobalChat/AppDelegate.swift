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


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

