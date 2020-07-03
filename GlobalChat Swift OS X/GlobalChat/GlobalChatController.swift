//
//  GlobalChatController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/3/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa

class GlobalChatController: NSViewController {
    
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var chat_message: NSTextField!
    @IBOutlet weak var chat_window: NSWindow!
    @IBOutlet weak var chat_window_text: NSTextView!
    @IBOutlet weak var nicks_table: NSTableView!
    @IBOutlet weak var scroll_view: NSScrollView!
    @IBOutlet weak var server_list_window: NSWindow!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
