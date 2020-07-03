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
    
    var nicks: [String]?
    var msg_count: Int = 0
    var handle: String = ""
    var host: String = ""
    var port: String = ""
    var password: String = ""
    var chat_buffer: String = ""
    var ts: GCDAsyncSocket = GCDAsyncSocket.init()
    var should_autoreconnect: Bool = false
    var connected: Bool = false
    
    let queue = DispatchQueue(label: "com.queue.Serial")
    
    
    
    
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
    
    func sign_on() {
        print("sign_on:")
        if (host == "" || port == "") {
            return;
        }

        ts = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try ts.connect(toHost: host, onPort:UInt16(port) ?? 9994, withTimeout: 30)
        } catch {
            print("Connect failed.")
        }
        
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
        DispatchQueue.main.sync {
            chat_window_text.isEditable = true
            chat_window_text.isAutomaticLinkDetectionEnabled = true
            chat_window_text.textStorage!.setAttributedString(NSAttributedString.init(string: self.chat_buffer))
            chat_window_text.checkTextInDocument(nil)
            chat_window_text.isEditable = false
        }
    }
    
    func update_chat_views() {
          DispatchQueue.main.sync {
            //let frame_height = self.scroll_view.documentView!.frame.size.height
            //let content_size = self.scroll_view.contentSize.height
            let y = chat_window_text.string.count
            self.scroll_view.drawsBackground = false
            self.chat_window_text.scrollRangeToVisible(NSRange.init(location: y, length: 0))
            self.scroll_view.reflectScrolledClipView(self.scroll_view.contentView)
        }
    }
}
