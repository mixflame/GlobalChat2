//
//  GlobalDrawController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/9/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa

class GlobalDrawController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}

class LineDrawer : NSView {
  var newLinear = NSBezierPath()

    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.set()
        newLinear.lineWidth = 1
        newLinear.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let location = event.locationInWindow
        var lastPt = event.locationInWindow
        lastPt.x -= frame.origin.x
        lastPt.y -= frame.origin.y
        newLinear.move(to: lastPt)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        var newPt = event.locationInWindow
        newPt.x -= frame.origin.x
        newPt.y -= frame.origin.y
        newLinear.line(to: newPt)
        needsDisplay = true
    }
}
