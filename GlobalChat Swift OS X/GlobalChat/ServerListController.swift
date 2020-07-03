//
//  ServerListController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/3/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa

class ServerListController: NSViewController, NSTableViewDataSource {
    
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
        get_servers()
    }
    
    func get_servers() {
        let url = URL(string: "http://nexus-msl.heroku.com/msl")!

        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            print(String(data: data, encoding: .utf8)!)
        }

        task.resume()
    }
    
    @IBAction func changeInfo(_ sender: Any) {
        
    }
    
    @IBAction func connect(_ sender: Any) {
        
    }
    
    @IBAction func refresh(_ sender: Any) {
        
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if names != nil {
            return names![row]
        } else {
            return 0
        }
    }

    func numberOfRows(in: NSTableView) -> Int {
        if names == nil {
            return 0
        } else {
            return names!.count
        }
    }
    
}
