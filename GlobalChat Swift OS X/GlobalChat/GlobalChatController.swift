//
//  GlobalChatController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/3/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

class GlobalChatController: NSViewController, NSTableViewDataSource, GCDAsyncSocketDelegate, NSTextFieldDelegate, NSTableViewDelegate {
    
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
    var sent_message_index : Int = 0
    var match_index : Int = 0
    
    let queue = DispatchQueue(label: "com.queue.Serial")
    
    let osxMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
    
    var last_key_was_tab : Bool = false
    var first_tab : Bool = false
    var tab_query : String = ""
    var tab_completion_index : Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        chat_message.delegate = self
        nicks_table.delegate = self
    }

  
    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        if tableView == self.nicks_table {
            if let tableColumn = tableColumn {
//                print("cell string value is \("\((cell as! NSTextFieldCell).stringValue)")")
                if osxMode == "Dark" {
                    if away_nicks.contains((cell as! NSTextFieldCell).stringValue) {
                        (cell as! NSTextFieldCell).textColor = NSColor.gray
                    } else {
                        (cell as! NSTextFieldCell).textColor = NSColor.white
                    }
                } else {
                    if away_nicks.contains((cell as! NSTextFieldCell).stringValue) {
                      (cell as! NSTextFieldCell).textColor = NSColor.gray
                    } else {
                      (cell as! NSTextFieldCell).textColor = NSColor.black
                    }
                }
            }
        }
    }

    
    func select_chat_text() {
      chat_message.selectText(self)
        chat_message.currentEditor()!.selectedRange = NSRange.init(location: chat_message.stringValue.count, length: 0)
    }
    
    func cycle_chat_messages() {
      chat_message.stringValue = sent_messages[sent_message_index % sent_messages.count]
    }
    
    func control(_ control: NSControl, textView fieldEditor: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        print("Selector method is (\(NSStringFromSelector(commandSelector)))")
        if commandSelector == #selector(NSStandardKeyBindingResponding.moveUp(_:)) {
            //Do something against ENTER key
            sent_message_index = sent_message_index + 1
            cycle_chat_messages()
            select_chat_text()
            return true
        } else if commandSelector == #selector(NSStandardKeyBindingResponding.moveDown(_:)) {
            //Do something against DELETE key
            sent_message_index = sent_message_index - 1
            cycle_chat_messages()
            select_chat_text()
            return true
        } else if commandSelector == #selector(NSStandardKeyBindingResponding.insertTab(_:)) {
            //Do something against TAB key
            if last_key_was_tab {
                first_tab = false
            } else {
                first_tab = true
            }
            last_key_was_tab = true

            let message = chat_message.stringValue
            
            if (first_tab) {
                print("first tab set tab query")
                tab_query = String(message.components(separatedBy: " ").last!)
                print("tab query is set to \(tab_query)")
            }
            if tab_query == "" { return true }

            let last_letters_before_tab = tab_query
            
            print("last letters before tab \(last_letters_before_tab)")
            var matches : [String] = []
            let regex = try! NSRegularExpression(pattern: tab_query)
            for nick in nicks {
                let nsString = nick as NSString
                let results = regex.matches(in: nick,
                range: NSRange(nick.startIndex..., in: nick))
                
                for match in results {
                    // what will be the code
                    let range = match.range
                    let matchString = nsString as String
                    print("match is \(range) \(matchString)")
                    matches.append(matchString)
                }
                
            }

            // print(matches)
            match_index = match_index + 1
            if matches.count > 0 {
                match_index = match_index % matches.count
                let match = matches[match_index]
            
                if first_tab {
                    // clear at position ??
                    // position would be the length of the string minus the length of the tabquery....
                    tab_completion_index = chat_message.stringValue.count
                    tab_completion_index -= tab_query.count
                }
                
                print("replacing at position \(tab_completion_index) with match ", match)
                let msg = chat_message.stringValue;

                let start_index = String.Index(utf16Offset: tab_completion_index, in: msg)
                
                let left_matter = msg.prefix(upTo: start_index)
                
                print(left_matter)
                
                chat_message.stringValue = left_matter + match;
            }
                
            return true
        }
        return false
    }
      
    @IBAction func quit(_ sender: Any) {
        if connected == false {
          application.terminate(self)
        } else {
          return_to_server_list()
        }
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
        print("Server: \(line)")
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
            output_to_chat_window("\(handle) has entered\n")
            nicks.append(handle)
//            @nicks.uniq!
            nicks_table.reloadData()
        } else if command == "LEAVE" {
            let handle = parr[1]
            output_to_chat_window("\(handle) has exited\n")
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
        
//        print(data)
        let line = String(bytes: data, encoding: .utf8)!
        parse_line(line)
        read_line()
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print(err.debugDescription)
        self.connected = false
        autoreconnect()
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
        print("autoreconnect:")
        queue.async {
            if self.should_autoreconnect != false {
                print("should autoreconnect")
                while(true) {
                    if self.connected == true {
                        print("reconnect successful.. breaking")
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
            if self.osxMode == "Dark" {
                self.chat_window_text.textColor = NSColor.white
            }
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
    
    func controlTextDidChange(_ notification: Notification) {
        //let textField = notification.object as? NSTextField
        //print("controlTextDidChange: stringValue == \(textField?.stringValue ?? "")")
        last_key_was_tab = false
    }
}
