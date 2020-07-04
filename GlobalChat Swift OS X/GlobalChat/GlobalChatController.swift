//
//  GlobalChatController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/3/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

class GlobalChatController: NSViewController, NSTableViewDataSource, GCDAsyncSocketDelegate {
    
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var chat_message: NSTextField!
    @IBOutlet weak var chat_window: NSWindow!
    @IBOutlet weak var chat_window_text: NSTextView!
    @IBOutlet weak var nicks_table: NSTableView!
    @IBOutlet weak var scroll_view: NSScrollView!
    @IBOutlet weak var server_list_window: NSWindow!
    
    var nicks: [String] = []
    var msg_count: Int = 0
    var handle: String = ""
    var host: String = ""
    var port: String = ""
    var password: String = ""
    var chat_buffer: String = ""
    var ts: GCDAsyncSocket = GCDAsyncSocket.init()
    var should_autoreconnect: Bool = false
    var connected: Bool = false
    var last_ping : Date = Date()
    var server_name: String = ""
    var chat_token: String = ""
    var away_nicks: [String] = []
    var sent_messages: [String] = []
    
    let queue = DispatchQueue(label: "com.queue.Serial")
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func quit(_ sender: Any) {
        
    }
    
    @IBAction func sendMessage(_ sender: NSTextField) {
      let message = sender.stringValue
        if message != "" {
            post_message(message)
            chat_message.stringValue = ""
            sent_messages.append(message)
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return nicks[row]
    }

    func numberOfRows(in: NSTableView) -> Int {
        return nicks.count
    }
    
    func post_message(_ message: String) {
        send_message("MESSAGE", args: [message, chat_token])
        add_msg(self.handle, message: message)
    }
    
    func sign_on() {
        print("sign_on:")
        if (host == "" || port == "") {
            return;
        }

        print("Connecting")
        ts = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try ts.connect(toHost: host, onPort:UInt16(port) ?? 9994, withTimeout: 30)
        } catch {
            print("Connect failed.")
        }
        
    }
  
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Connected")
        should_autoreconnect = true
        connected = true
        last_ping = Date()
        var sign_on_array: Array<String>
        if password == "" {
            sign_on_array = [handle]
        } else {
            sign_on_array = [handle, password]
        }
        send_message("SIGNON", args: sign_on_array)
        should_autoreconnect = true
        read_line()
    }
    
    func parse_line(_ line: String) {
        let parr = line.components(separatedBy: "::!!::")
        let command = parr.first
        if command == "TOKEN" {
            chat_token = parr[1]
            handle = parr[2]
            server_name = parr[3]
            ping()
            show_chat()
            get_log()
            get_handles()
            connected = true
        } else if command == "HANDLES" {
            nicks = parr.last!.components(separatedBy: "\n")
            nicks_table.reloadData()
        } else if command == "PONG" {
            nicks = parr.last!.components(separatedBy: "\n")
            nicks_table.reloadData()
            ping()
        } else if command == "BUFFER" {
            let buffer : String = parr[1]
            if buffer != "" {
              chat_buffer = buffer
              update_and_scroll()
            }
        } else if command == "SAY" {
            let handle = parr[1]
            let msg = parr[2]
            add_msg(handle, message: msg)
        } else if command == "JOIN" {
            let handle = parr[1]
            output_to_chat_window("#{handle} has entered\n")
            nicks.append(handle)
//            @nicks.uniq!
            nicks_table.reloadData()
        } else if command == "LEAVE" {
            let handle = parr[1]
            output_to_chat_window("#{handle} has exited\n")
            nicks = nicks.filter { $0 != handle }
            nicks_table.reloadData()
        } else if command == "ALERT" {
            let text = parr[1]
            alert(text)
            return_to_server_list()
        }
    }
    
    func cleanup() {
      chat_message.stringValue = ""
      nicks = []
      nicks_table.reloadData()
      chat_window_text.string = ""
    }
    
    func sign_out() {
        send_message("SIGNOFF", args: [chat_token])
        ts.disconnect()
    }

    func return_to_server_list() {
        should_autoreconnect = false
        sign_out()
        DispatchQueue.main.async {
            self.server_list_window.makeKeyAndOrderFront(nil)
            self.chat_window.orderOut(self)
            self.cleanup()
            self.connected = false
        }
    }
    
    
    func alert(_ msg: String) {
        DispatchQueue.main.async {
            let alert = NSAlert.init()
            alert.messageText = msg
            alert.runModal()
        }
    }
    
    func check_if_pinged(_ handle: String, message: String) {
        if self.handle != handle && message.contains(handle) {
        NSSound.beep()
//        Notification.send(handle, message)
            NSApp.requestUserAttention(NSApplication.RequestUserAttentionType(rawValue: 0)!)
        msg_count = msg_count + 1
            NSApplication.shared.dockTile.badgeLabel = String(msg_count)
        }
    }
    
    func check_if_away_or_back(_ handle: String, message: String) {
        if message.contains("brb") {
            away_nicks.append(handle)
        } else if message.contains("back") {
            away_nicks = away_nicks.filter { $0 != handle }
        }
    }
    
    func add_msg(_ handle: String, message: String) {
        check_if_pinged(handle, message: message)
        check_if_away_or_back(handle, message: message)
        let msg = "\(handle): \(message)\n"
        output_to_chat_window(msg)
    }
    
    func get_handles() {
        send_message("GETHANDLES", args: [chat_token])
    }
    
    func get_log() {
        send_message("GETBUFFER", args: [chat_token])
    }
    
    func ping() {
        last_ping = Date()
        send_message("PING", args: [self.chat_token])
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        print(data)
        let line = String(bytes: data, encoding: .utf8)!
        parse_line(line)
        read_line()
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print(err.debugDescription)
    }
    
    func send_message(_ opcode: String, args: Array<String>) {
        let msg = opcode + "::!!::" + args.joined(separator: "::!!::") + "\0"
        print("Client: \(msg)")
        let data = msg.data(using: String.Encoding.utf8)
        ts.write(data, withTimeout:-1, tag: 0)
    }
    
    func read_line() {
        ts.readData(to: GCDAsyncSocket.zeroData(), withTimeout:-1, tag:0)
        
        if last_ping < Date() - 30 {
            autoreconnect()
        }
    }
    
    func show_chat() {
        DispatchQueue.main.async {
            self.server_list_window.orderOut(self)
            self.chat_window.makeKeyAndOrderFront(nil)
            if self.server_name != "" {
                self.log("Connected to \(self.server_name) \n")
                self.chat_window.title = self.server_name
            }
        }
    }
    
    func log(_ str: String) {
        print(str)
        output_to_chat_window(str)
    }
    
    
    func autoreconnect() {
        queue.async {
            if self.should_autoreconnect != false {
            while(true) {
                if self.connected == true {
                    break
                }
              DispatchQueue.main.sync {
                self.output_to_chat_window("Could not connect to GlobalChat. Will retry in 5 seconds..")
                print("connected? \(self.connected)")
                self.sign_on()
                }
              sleep(5)
                }
            }
        }
    }
    
    func output_to_chat_window(_ str: String) {
        self.chat_buffer = self.chat_buffer + str
        update_and_scroll()
    }
    
    func update_and_scroll() {
      parse_links()
      update_chat_views()
    }
    

    func parse_links() {
        DispatchQueue.main.async {
            self.chat_window_text.isEditable = true
            self.chat_window_text.isAutomaticLinkDetectionEnabled = true
            self.chat_window_text.textStorage!.setAttributedString(NSAttributedString.init(string: self.chat_buffer))
            self.chat_window_text.checkTextInDocument(nil)
            self.chat_window_text.isEditable = false
        }
    }
    
    func update_chat_views() {
          DispatchQueue.main.async {
            //let frame_height = self.scroll_view.documentView!.frame.size.height
            //let content_size = self.scroll_view.contentSize.height
            let y = self.chat_window_text.string.count
            self.scroll_view.drawsBackground = false
            self.chat_window_text.scrollRangeToVisible(NSRange.init(location: y, length: 0))
            self.scroll_view.reflectScrolledClipView(self.scroll_view.contentView)
        }
    }
}
