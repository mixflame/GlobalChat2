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
    
    var names: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
//        get_servers()
    }
    
    func get_servers() {
        self.names = []
        
        let url = URL(string: "https://nexus-msl.herokuapp.com/msl")!

        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            print(String(data: data, encoding: .utf8)!)
            let data_string = String(data: data, encoding: .utf8)
            let each_line = data_string!.split(separator: Character("\n"))
            for server in each_line {
                let server_info = server.components(separatedBy: "-!!!-")
                let name = server_info[0]
                let ip = server_info[1]
                let port = server_info[2]
                self.names.append(String(name))
            }
            
            
            DispatchQueue.main.async {
                self.server_list_table.reloadData()
            }
            
        }

        task.resume()
    }
    
    @IBAction func changeInfo(_ sender: Any) {
        
    }
    
    @IBAction func connect(_ sender: Any) {
        
    }
    
    @IBAction func refresh(_ sender: Any) {
        get_servers()
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        print(self.names)
        return self.names[row]
    }

    func numberOfRows(in: NSTableView) -> Int {
        return self.names.count
    }
    
}
