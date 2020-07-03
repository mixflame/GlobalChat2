//
//  GlobalChatController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/3/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

class GlobalChatController: NSViewController, NSTableViewDataSource {
    
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var chat_message: NSTextField!
    @IBOutlet weak var chat_window: NSWindow!
    @IBOutlet weak var chat_window_text: NSTextView!
    @IBOutlet weak var nicks_table: NSTableView!
    @IBOutlet weak var scroll_view: NSScrollView!
    @IBOutlet weak var server_list_window: NSWindow!
    
    var nicks: [String]?
    var msg_count: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func quit(_ sender: Any) {
        
    }
    
    @IBAction func sendMessage(_ sender: Any) {
        
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if nicks != nil {
            return nicks![row]
        } else {
            return 0
        }
    }

    func numberOfRows(in: NSTableView) -> Int {
        if nicks == nil {
            return 0
        } else {
            return nicks!.count
        }
    }
}
