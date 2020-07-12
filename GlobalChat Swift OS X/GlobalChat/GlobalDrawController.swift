//
//  GlobalDrawController.swift
//  GlobalChat
//
//  Created by Jonathan Silverman on 7/9/20.
//  Copyright © 2020 Jonathan Silverman. All rights reserved.
//

import Cocoa
import CoreGraphics

class GlobalDrawController: NSViewController {
    
    @IBOutlet weak var drawing_view: NSView!
    
    var gcc: GlobalChatController?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        print("viewDidLoad: gdc")
    }
    
}

class LineDrawer : NSImageView {
    var newLinear = NSBezierPath()
    
    
    var points : [[String : Any]] = []
    
    var nameHash : [String : Int] = [:] // which layer is this handle on
    
    var layerOrder : [String] = [] // which order to draw layers
    
    var layers : [String : Any] = [:] // which points are in a layer
    
//    var username : String = ""
    
    var scribbling : Bool = false
    var pen_color : NSColor = NSColor.black.usingColorSpace(NSColorSpace.deviceRGB)!
    var pen_width : CGFloat = CGFloat(1)
    
    
    func addClick(_ x: CGFloat, y: CGFloat, dragging: Bool, red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat, width: CGFloat, clickName: String) {
        var point : [String : Any] = [:]
        point["x"] = x
        point["y"] = y
        point["dragging"] = dragging
        point["red"] = red
        point["green"] = green
        point["blue"] = blue
        point["alpha"] = alpha
        point["width"] = width
        point["clickName"] = clickName
        points.append(point)
        
        var layerName : String = ""
        
        if(nameHash[clickName] == nil) {
            let layer = 0
            nameHash[clickName] = layer
            layerName = "\(clickName)_\(layer)"
            let layerArray : [[String : Any]] = []
            layers[layerName] = layerArray
        } else {
            if(dragging == false) {
                let layer = nameHash[clickName]! + 1
                nameHash[clickName] = layer
                layerName = "\(clickName)_\(layer)"
                let layerArray : [[String : Any]] = []
                layers[layerName] = layerArray
            } else {
                let layer = nameHash[clickName]!
                layerName = "\(clickName)_\(layer)"
            }
        }
        
        var tempLayers = layers[layerName] as! [[String : Any]]
        tempLayers.append(point)
        layers[layerName] = tempLayers
        
        if(!layerOrder.contains(layerName)) {
            layerOrder.append(layerName)
        }
        
    }
    
    func drawLineTo(_ lastPoint : CGPoint, _ endPoint : CGPoint, _ penColor : NSColor, _ penWidth : CGFloat) {
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setStrokeColor(penColor.cgColor)
        context.setLineWidth(penWidth)
        context.move(to: lastPoint)
        context.addLine(to: endPoint)
        context.strokePath()
//        newLinear.move(to: lastPoint)
//        newLinear.line(to: endPoint)
//        penColor.set()
//        newLinear.lineWidth = penWidth
//        newLinear.stroke()
    }
    
    
    func redraw() {
        NSColor.white.setFill() // allow configuration of this later
        bounds.fill()
        
        for layer in layerOrder {
            let layerArray = layers[layer] as! [[String : Any]]
            for i in 1...layerArray.count - 1 {
                let lastObj = layerArray[i - 1] as [String : Any]
                let lastPoint : CGPoint = CGPoint(x: lastObj["x"] as! CGFloat, y: lastObj["y"] as! CGFloat)
                let thisObj = layerArray[i] as [String : Any]
                let thisPoint : CGPoint = CGPoint(x: thisObj["x"] as! CGFloat, y: thisObj["y"] as! CGFloat)
                if(thisObj["dragging"] as! Bool && lastObj["dragging"] as! Bool) {
                    let red = lastObj["red"] as! CGFloat
                    let green = lastObj["green"] as! CGFloat
                    let blue = lastObj["blue"] as! CGFloat
                    let alpha = lastObj["alpha"] as! CGFloat
                    let penColor : NSColor = NSColor.init(red: red, green: green, blue: blue, alpha: alpha)
                    let penWidth = lastObj["width"] as! CGFloat
                    drawLineTo(lastPoint, thisPoint, penColor, penWidth)
                }
            }
        }
    }

    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let objectFrame: NSRect = self.frame
        if self.needsToDraw(objectFrame) {
            // drawing code for object
            redraw()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let gdc = self.window?.contentViewController as! GlobalDrawController
        super.mouseDown(with: event)
        scribbling = true
        
        var lastPt = convert(event.locationInWindow, from: nil)
        lastPt.x -= frame.origin.x
        lastPt.y -= frame.origin.y
        
        addClick(lastPt.x, y: lastPt.y, dragging: false, red: pen_color.redComponent, green: pen_color.greenComponent, blue: pen_color.blueComponent, alpha: pen_color.alphaComponent, width: pen_width, clickName: gdc.gcc!.handle)
        
        send_point(lastPt.x, y: lastPt.y, dragging: false, red: pen_color.redComponent, green: pen_color.greenComponent, blue: pen_color.blueComponent, alpha: pen_color.alphaComponent, width: pen_width, clickName: gdc.gcc!.handle)
        
    }

    override func mouseDragged(with event: NSEvent) {
        let gdc = self.window?.contentViewController as! GlobalDrawController
        super.mouseDragged(with: event)
        var newPt = convert(event.locationInWindow, from: nil)
        newPt.x -= frame.origin.x
        newPt.y -= frame.origin.y
        
        addClick(newPt.x, y: newPt.y, dragging: true, red: pen_color.redComponent, green: pen_color.greenComponent, blue: pen_color.blueComponent, alpha: pen_color.alphaComponent, width: pen_width, clickName: gdc.gcc!.handle)
        
        
        send_point(newPt.x, y: newPt.y, dragging: true, red: pen_color.redComponent, green: pen_color.greenComponent, blue: pen_color.blueComponent, alpha: pen_color.alphaComponent, width: pen_width, clickName: gdc.gcc!.handle)

        needsDisplay = true
        
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        scribbling = false
        
    }
    
    
    func send_point(_ x: CGFloat, y: CGFloat, dragging: Bool, red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat, width: CGFloat, clickName: String) {
        let gdc = self.window?.contentViewController as! GlobalDrawController
        var point : [String] = []
        point.append(String(x.description))
        point.append(String(y.description))
        point.append(String(dragging.description))
        point.append(String(red.description))
        point.append(String(green.description))
        point.append(String(blue.description))
        point.append(String(alpha.description))
        point.append(String(width.description))
        point.append(String(gdc.gcc!.chat_token))
        gdc.gcc?.send_message("POINT", args: point)
    }
    
}
