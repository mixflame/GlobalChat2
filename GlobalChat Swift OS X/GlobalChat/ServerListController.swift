//
//  ServerListController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/3/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa

class ServerListController: NSViewController {
    
    @IBOutlet weak var server_list_window: NSWindow!
    @IBOutlet weak var chat_window: NSWindow!
    @IBOutlet weak var gcc: GlobalChatController!
    @IBOutlet weak var handle: NSTextField!
    @IBOutlet weak var host: NSTextField!
    @IBOutlet weak var port: NSTextField!
    @IBOutlet weak var password: NSTextField!
    @IBOutlet weak var server_list_table: NSTableView!
    
    var names: [String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any {
        if names != nil {
            return names![row]
        } else {
            return 0
        }
    }

    func numberOfRowsInTableView(_ in: NSTableView) -> Int {
        if names == nil {
            return 0
        } else {
            return names!.count
        }
    }
    
}
