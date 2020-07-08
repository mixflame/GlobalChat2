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
    var server_list_hash: [[String:String]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        print("view did load")
    }
    
    
    
    func get_servers() {
        print("get_servers:")
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
                self.server_list_hash.append(["name": name, "ip": ip, "port": port])
            }
            
            
            DispatchQueue.main.async {
                self.server_list_table.reloadData()
            }
            
        }

        task.resume()
    }
    
    @IBAction func changeInfo(_ sender: NSTableView) {
        if(sender.selectedRow == -1) {
            return
        }
        self.host.stringValue = self.server_list_hash[sender.selectedRow]["ip"] ?? ""
        self.port.stringValue = self.server_list_hash[sender.selectedRow]["port"] ?? ""
    }
    
    @IBAction func connect(_ sender: Any) {
        print("connect:")
        let prefs = UserDefaults.standard
        prefs.set(host.stringValue, forKey: "host")
        prefs.set(handle.stringValue, forKey: "handle")
        prefs.set(port.stringValue, forKey: "port")

        gcc.handle = handle.stringValue
        gcc.host = host.stringValue
        gcc.port = port.stringValue
        gcc.password = password.stringValue
        gcc.nicks = []
        gcc.chat_buffer = ""

        gcc.sign_on()

    }
    
    @IBAction func refresh(_ sender: Any) {
        get_servers()
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return self.names[row]
    }

    func numberOfRows(in: NSTableView) -> Int {
        if self.names.count == 0 {
            return 0
        }
        return self.names.count
    }
    
}
