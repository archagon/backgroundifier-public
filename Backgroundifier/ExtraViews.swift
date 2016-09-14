//
//  ExtraViews.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-8-31.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

import Foundation

protocol DraggityDropDestination: class {
    func dropperShouldBegin(dropper: NSView, files: [NSURL]) -> Bool
    func dropperSupportedFiletypes(dropper: NSView) -> [String]
    func dropperDraggingEntered(dropper: NSView)
    func dropperDraggingExited(dropper: NSView)
    func dropperDraggingEnded(dropper: NSView)
    func dropperDidGetFiles(dropper: NSView, files: [NSURL]) -> Bool
}

class ShadowView : NSView {
    var blur: CGFloat = 10.25
    var rect: NSRect = NSMakeRect(0, 0, 0, 0)
    
    override func drawRect(dirtyRect: NSRect) {
        if let ctx = NSGraphicsContext.currentContext()?.CGContext {
            CGContextSaveGState(ctx)
            
            let shadowPath = NSBezierPath(rect: self.rect)
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0), blur, NSColor.blackColor().colorWithAlphaComponent(0.5).CGColor)
            NSColor.blackColor().setFill()
            shadowPath.fill()
            CGContextRestoreGState(ctx)
        }
    }
}

class DragDroppableView : NSView {
    weak var delegate: DraggityDropDestination? {
        didSet {
            register()
        }
    }
    
    var enabled: Bool = true
    
    func register() -> Bool {
        if let delegate = self.delegate {
            self.registerForDraggedTypes(delegate.dropperSupportedFiletypes(self))
            return true
        }
        else {
            return false
        }
    }
    
    override func prepareForDragOperation(sender: NSDraggingInfo) -> Bool {
        return self.enabled
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        if self.enabled {
            self.delegate?.dropperDraggingEntered(self)
            return NSDragOperation.Copy
        }
        else {
            return NSDragOperation.None
        }
    }
    
    override func draggingExited(sender: NSDraggingInfo?) {
        if self.enabled {
            self.delegate?.dropperDraggingExited(self)
        }
    }
    
    override func draggingEnded(sender: NSDraggingInfo?) {
        if self.enabled {
            self.delegate?.dropperDraggingEnded(self)
        }
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if !enabled {
            return false
        }
        
        let classArray: [AnyClass] = [ NSURL.self ]
        let returnArray = sender.draggingPasteboard().readObjectsForClasses(classArray, options: [ NSPasteboardURLReadingFileURLsOnlyKey : true ])
        
        if let urlArray = returnArray as? [NSURL], delegate = self.delegate {
            return delegate.dropperDidGetFiles(self, files: urlArray)
        }
        else {
            return false
        }
    }
}

class DropletView : DragDroppableView {
    var highlightColor: NSColor? {
        didSet {
            self.setNeedsDisplayInRect(self.bounds)
        }
    }
    var borderColor: NSColor? {
        didSet {
            self.setNeedsDisplayInRect(self.bounds)
        }
    }
    var borderSolid: Bool = false {
        didSet {
            self.setNeedsDisplayInRect(self.bounds)
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        
        let lineWidth: CGFloat = (self.borderColor != nil ? 3 : 0)
        
        let smallerRect = CGRectMake(lineWidth / CGFloat(2), lineWidth / CGFloat(2), self.bounds.size.width - lineWidth, self.bounds.size.height - lineWidth)
        let path = NSBezierPath(roundedRect: smallerRect, xRadius: 10, yRadius: 10)
        
        if self.highlightColor != nil {
            self.highlightColor!.setFill()
            path.fill()
        }
        
        if let borderColor = self.borderColor {
            path.lineWidth = lineWidth
            
            if !self.borderSolid {
                // this doesn't do what I wanted, but it looks good enough for now
                let short: CGFloat = self.bounds.size.width / 40
                let long: CGFloat = 3 * short
                
                let pattern: [CGFloat] = [ long, short ]
                path.setLineDash(pattern, count: 2, phase: 0)
            }
            
            borderColor.setStroke()
            path.stroke()
        }
        
        NSGraphicsContext.restoreGraphicsState()
    }
}

// this view prevents the auto/color segmented control from appearing dark when the big color button is selected
class AutoColorBackingView: NSView {
    override func drawRect(dirtyRect: NSRect) {
        let borderWidth: CGFloat = 1
        
        let path = NSBezierPath(roundedRect: NSMakeRect(borderWidth / 2.0, borderWidth / 2.0, self.bounds.size.width - borderWidth, self.bounds.size.height - borderWidth), xRadius: 4, yRadius: 4)
        path.lineWidth = borderWidth
        
        NSColor.whiteColor().setFill()
        path.fill()
        
        let grayColorValue: CGFloat = 200.0
        NSColor(red: grayColorValue/255.0, green: grayColorValue/255.0, blue: grayColorValue/255.0, alpha: 1).setStroke()
        path.stroke()
    }
}

// cell for the blur/color picker
class CustomButtonCell : NSButtonCell {
    var top: Bool = true
    
    // NSSegmentedControl colors aquired through pipette; inaccurate because of color space conversion, but whatever
    let onColor = NSColor(red: 163.0/255.0, green: 163.0/255.0, blue: 163.0/255.0, alpha: 1)
    let onColorSelected = NSColor(red: 120.0/255.0, green: 120.0/255.0, blue: 120.0/255.0, alpha: 1)
    let onColorDisabled = NSColor(red: 208.0/255.0, green: 208.0/255.0, blue: 208.0/255.0, alpha: 1)
    let onTextColor = NSColor.whiteColor()
    let onTextColorSelected = NSColor(red: 234.0/255.0, green: 234.0/255.0, blue: 234.0/255.0, alpha: 1)
    let onTextColorDisabled = NSColor(red: 146.0/255.0, green: 146.0/255.0, blue: 146.0/255.0, alpha: 1)
    let offColor = NSColor.whiteColor()
    let offColorSelected = NSColor(red: 223.0/255.0, green: 223.0/255.0, blue: 223.0/255.0, alpha: 1)
    let offColorDisabled = NSColor.whiteColor()
    let offTextColor = NSColor(red: 28.0/255.0, green: 28.0/255.0, blue: 28.0/255.0, alpha: 1)
    let offTextColorSelected = NSColor(red: 26.0/255.0, green: 26.0/255.0, blue: 26.0/255.0, alpha: 1)
    let offTextColorDisabled = NSColor(red: 178.0/255.0, green: 178.0/255.0, blue: 178.0/255.0, alpha: 1)
    let borderColor = NSColor(red: 163.0/255.0, green: 163.0/255.0, blue: 163.0/255.0, alpha: 1)
    let borderColorOnSelected = NSColor(red: 234.0/255.0, green: 234.0/255.0, blue: 234.0/255.0, alpha: 1)
    let borderColorOffSelected = NSColor(red: 163.0/255.0, green: 163.0/255.0, blue: 163.0/255.0, alpha: 1)
    let borderColorDisabled = NSColor(red: 208.0/255.0, green: 208.0/255.0, blue: 208.0/255.0, alpha: 1)
    
    override func drawBezelWithFrame(frame: NSRect, inView controlView: NSView) {
        NSGraphicsContext.saveGraphicsState()
        
        let cornerRadius = CGFloat(10)
        let lineWidth = CGFloat((self.highlighted ? 1 : 1))
        
        let frame: NSRect = { () -> NSRect in
            if self.top {
                return NSMakeRect(frame.origin.x + lineWidth / CGFloat(2), frame.origin.y + lineWidth / CGFloat(2), frame.size.width - lineWidth, frame.size.height - lineWidth / CGFloat(2))
            }
            else {
                return NSMakeRect(frame.origin.x + lineWidth / CGFloat(2), frame.origin.y, frame.size.width - lineWidth, frame.size.height - lineWidth / CGFloat(2))
            }
        }()
        
        let clipPath: NSBezierPath = NSBezierPath()
        
        if (self.top) {
            clipPath.moveToPoint(NSMakePoint(frame.origin.x, frame.origin.y + frame.size.height))
            clipPath.lineToPoint(NSMakePoint(frame.origin.x, frame.origin.y + cornerRadius))
            clipPath.appendBezierPathWithArcWithCenter(NSMakePoint(frame.origin.x + cornerRadius, frame.origin.y + cornerRadius), radius: cornerRadius, startAngle: 180, endAngle:270, clockwise: false)
            clipPath.lineToPoint(NSMakePoint(frame.origin.x + frame.size.width - cornerRadius, frame.origin.y))
            clipPath.appendBezierPathWithArcWithCenter(NSMakePoint(frame.origin.x + frame.size.width - cornerRadius, frame.origin.y + cornerRadius), radius: cornerRadius, startAngle: 270, endAngle:0, clockwise: false)
            clipPath.lineToPoint(NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height))
        }
        else {
            clipPath.moveToPoint(NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y))
            clipPath.lineToPoint(NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height - cornerRadius))
            clipPath.appendBezierPathWithArcWithCenter(NSMakePoint(frame.origin.x + frame.size.width - cornerRadius, frame.origin.y + frame.size.height - cornerRadius), radius: cornerRadius, startAngle: 0, endAngle:90, clockwise: false)
            clipPath.lineToPoint(NSMakePoint(frame.origin.x + cornerRadius, frame.origin.y + frame.size.height))
            clipPath.appendBezierPathWithArcWithCenter(NSMakePoint(frame.origin.x + cornerRadius, frame.origin.y + frame.size.height - cornerRadius), radius: cornerRadius, startAngle: 90, endAngle:180, clockwise: false)
            clipPath.lineToPoint(NSMakePoint(frame.origin.x, frame.origin.y))
        }
        
        let strokePath: NSBezierPath = clipPath.copy() as! NSBezierPath
        strokePath.lineWidth = lineWidth
        
        var fillColor: NSColor?
        var strokeColor: NSColor?
        
        if self.state == NSOnState {
            if !self.enabled {
                fillColor = self.onColorDisabled
                strokeColor = self.borderColorDisabled
            }
            else if self.highlighted {
                fillColor = self.onColorSelected
                strokeColor = self.borderColorOnSelected
            }
            else {
                fillColor = self.onColor
                strokeColor = self.borderColor
            }
        }
        else {
            if !self.enabled {
                fillColor = self.offColorDisabled
                strokeColor = self.borderColorDisabled
            }
            else if self.highlighted {
                fillColor = self.offColorSelected
                strokeColor = self.borderColorOffSelected
            }
            else {
                fillColor = self.offColor
                strokeColor = self.borderColor
            }
        }
        
        fillColor = fillColor?.colorUsingColorSpace(NSColorSpace.deviceRGBColorSpace())
        strokeColor = strokeColor?.colorUsingColorSpace(NSColorSpace.deviceRGBColorSpace())
        
        fillColor?.setFill()
        strokePath.fill()
        
        strokeColor?.setStroke()
        strokePath.stroke()
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    override func drawTitle(title: NSAttributedString, withFrame frame: NSRect, inView controlView: NSView) -> NSRect {
        var textColor: NSColor?
        
        if self.state == NSOnState {
            if !self.enabled {
                textColor = self.onTextColorDisabled
            }
            else if self.highlighted {
                textColor = self.onTextColorSelected
            }
            else {
                textColor = self.onTextColor
            }
        }
        else {
            if !self.enabled {
                textColor = self.offTextColorDisabled
            }
            else if self.highlighted {
                textColor = self.offTextColorSelected
            }
            else {
                textColor = self.offTextColor
            }
        }
        
        textColor = textColor?.colorUsingColorSpace(NSColorSpace.deviceRGBColorSpace())
        
        if let textColor = textColor {
            let colorTitle = NSMutableAttributedString(attributedString: self.attributedTitle)
            let titleRange = NSMakeRange(0, colorTitle.length)
            colorTitle.addAttribute(NSForegroundColorAttributeName, value: textColor, range: titleRange)
            self.attributedTitle = colorTitle
        }
        
        return super.drawTitle(self.attributedTitle, withFrame: frame, inView: controlView)
    }
}

class CustomButton : NSButton {
    override var alignmentRectInsets: NSEdgeInsets {
        let insets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        return insets
    }
}

class CustomSegmentedCell : NSSegmentedCell {
}
