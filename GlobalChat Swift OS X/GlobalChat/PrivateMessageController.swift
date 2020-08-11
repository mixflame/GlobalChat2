//
//  PrivateMessageController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/5/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa

class PrivateMessageController: NSViewController, NSTextFieldDelegate {

    @IBOutlet weak var scroll_view: NSScrollView!
    @IBOutlet weak var pm_window_text: NSTextView!
    @IBOutlet weak var chat_message: NSTextField!
    
    var handle : String = "" // their handle
    var gcc: GlobalChatController?
    var pm_buffer : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        print("pm window loaded \(gcc!.handle) and \(handle)")
        chat_message.delegate = self
    }
    
    @IBAction func sendMessage(_ sender: NSTextField) {
        print("sendMessage:")
        let message = sender.stringValue
        if message == "" {
            return
        }
        gcc!.priv_msg(handle, message: message)
        chat_message.stringValue = ""
    }

    func output_to_chat_window(_ str: String) {
        self.pm_buffer = self.pm_buffer + str
        update_and_scroll()
    }
    
    func update_and_scroll() {
      parse_links()
      update_chat_views()
    }
    
    func parse_links() {
        self.pm_window_text.isEditable = true
        self.pm_window_text.isAutomaticLinkDetectionEnabled = true
        self.pm_window_text.textStorage!.setAttributedString(NSAttributedString.init(string: self.pm_buffer))
        if self.gcc!.osxMode == "Dark" {
            self.pm_window_text.textColor = NSColor.white
        }
        self.pm_window_text.checkTextInDocument(nil)
        self.pm_window_text.isEditable = false
    }
    
    func update_chat_views() {
        //let frame_height = self.scroll_view.documentView!.frame.size.height
        //let content_size = self.scroll_view.contentSize.height
        let y = self.pm_window_text.string.count
        self.scroll_view.drawsBackground = false
        self.pm_window_text.scrollRangeToVisible(NSRange.init(location: y, length: 0))
        self.scroll_view.reflectScrolledClipView(self.scroll_view.contentView)
    }
    
}
