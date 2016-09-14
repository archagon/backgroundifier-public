//
//  ViewController_DropletView.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-9-14.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

extension ViewController {
    func varyDropper(t: CGFloat) {
        // TODO: this is wacky and brittle
        if let container = self.dropletContainer, let shadow = self.dropletShadow {
            let minimumScale: CGFloat = 0.85
            let maximumScale: CGFloat = 0.90
            let scale: CGFloat = minimumScale + (maximumScale - minimumScale) * t
            
            container.scaleUnitSquareToSize(container.convertSize(NSMakeSize(1, 1), fromView: nil))
            container.scaleUnitSquareToSize(NSMakeSize(scale, scale))
            container.bounds.origin = NSMakePoint((container.frame.size.width - container.bounds.size.width) / 2.0, (container.frame.size.height - container.bounds.size.height) / 2.0)
            
            // TODO: wrong measurements
            let shadowScale: CGFloat = 0.95
            var shadowRect = NSMakeRect(0, 0, container.frame.size.width * scale * shadowScale, container.frame.size.height * scale * shadowScale)
            shadowRect.origin = NSMakePoint((shadow.bounds.size.width - shadowRect.size.width) / 2.0, (shadow.bounds.size.height - shadowRect.size.height) / 2.0)
            
            shadow.rect = shadowRect
            //let shadowT: CGFloat = (1 - t)
            shadow.blur = CGFloat(5) + t * CGFloat(15)
            shadow.setNeedsDisplayInRect(shadow.bounds)
        }
    }
    
    func varyDropperT() -> CGFloat {
        if let container = self.dropletContainer {
            let minimumScale: CGFloat = 0.85
            let maximumScale: CGFloat = 0.90
            let scale: CGFloat = 1 / container.convertSize(NSMakeSize(1, 1), fromView: nil).width
            let t: CGFloat = (scale - minimumScale) / (maximumScale - minimumScale)
            return t
        }
        else {
            return 0
        }
    }
    
    func dropperTimerCallback(timer: NSTimer) {
        if let animation = self.dropperAnimation {
            let time = CACurrentMediaTime()
            let deltaTime = time - animation.startTime
            let inputT = deltaTime / animation.duration
            
            if inputT > 1 {
                animation.actionFunction(t: animation.timingFunction(duration: animation.duration, t: 1))
                animation.timer.invalidate()
                self.dropperAnimation = nil
            }
            else {
                animation.actionFunction(t: animation.timingFunction(duration: animation.duration, t: inputT))
            }
        }
    }
    
    func dropperSetupTimer(startingT: Double, duration: Double, timingFunction: ((duration: Double, t: Double) -> Double)) {
        if let animation = self.dropperAnimation {
            animation.timer.invalidate()
            self.dropperAnimation = nil
        }
        
        let durationAlreadyPlayed = startingT * duration
        let startTime = CACurrentMediaTime()
        let originalStartTime = startTime - durationAlreadyPlayed
        
        let timer = NSTimer(timeInterval: 1/60.0, target: self, selector: #selector(ViewController.dropperTimerCallback(_:)), userInfo: nil, repeats: true)
        
        let action = { (t: Double) -> Void in
            self.varyDropper(CGFloat(t))
        }
        
        self.dropperAnimation = (timer: timer, startTime: originalStartTime, duration: duration, timingFunction: timingFunction, actionFunction: action)
        NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
    }
    
    func dropperLift() {
        self.dropperSetupTimer(Double(varyDropperT()), duration: 0.15, timingFunction: { (duration: Double, t: Double) -> Double in
            return easeOutCubic(duration * t, b: 0, c: 1, d: duration)
        })
    }
    
    func dropperDrop() {
        self.dropperSetupTimer(Double(1 - varyDropperT()), duration: 0.5, timingFunction: { (duration: Double, t: Double) -> Double in
            return easeOutBounce(duration * t, b: 1, c: -1, d: duration)
        })
    }
    
    func dropperBounce() {
        let upTime: Double = 0.15
        let downTime: Double = 0.5
        self.dropperSetupTimer(0, duration: upTime + downTime, timingFunction: { (duration: Double, t: Double) -> Double in
            let time = duration * t
            
            if time < upTime {
                return easeOutCubic(time, b: 0, c: 1, d: upTime)
            }
            else if time < upTime + downTime {
                return easeOutBounce(time - upTime, b: 1, c: -1, d: downTime)
            }
            else {
                return 0
            }
        })
    }
    
    func dropletNonHoverMode() -> DropletMode {
        if self.files.count > 0 {
            if self.processing {
                if self.shouldStopProcessingFlag {
                    return .Cancelling
                }
                else {
                    return .Processing
                }
            }
            else {
                // simple heuristic
                if files.last?.status != FileStatus.Ready {
                    return .Done
                }
                else {
                    return .Ready
                }
            }
        }
        else {
            return .Default
        }
    }
    
    func setDropletMode(mode: DropletMode) {
        switch mode {
        case .Default:
            self.droplet?.highlightColor = NSColor.whiteColor()
            self.droplet?.borderColor = NSColor.lightGrayColor()
            self.droplet?.borderSolid = false
            self.dropletLabel?.hidden = false
            self.dropletStart?.hidden = true
            self.dropletClear?.hidden = true
            self.dropletDone?.hidden = true
            self.dropletCancel?.hidden = true
            self.dropletSpinner?.hidden = true
            self.dropletBar?.hidden = true
            self.dropletStart?.enabled = false
            self.dropletClear?.enabled = false
            self.dropletDone?.enabled = false
            self.dropletCancel?.enabled = false
            self.dropletSpinner?.alphaValue = 1
            self.dropletSpinner?.stopAnimation(self)
            self.dropletBar?.stopAnimation(self)
            self.setUIEnabled(true)
            self.dropperDrop()
        case .Hover:
            self.droplet?.highlightColor = NSColor.greenColor()
            self.droplet?.borderColor = NSColor(hue: CGFloat(120/360.0), saturation: 1, brightness: 0.75, alpha: 1)
            self.droplet?.borderSolid = false
            self.dropletLabel?.hidden = false
            self.dropletStart?.hidden = true
            self.dropletClear?.hidden = true
            self.dropletDone?.hidden = true
            self.dropletCancel?.hidden = true
            self.dropletSpinner?.hidden = true
            self.dropletBar?.hidden = true
            self.dropletStart?.enabled = false
            self.dropletClear?.enabled = false
            self.dropletDone?.enabled = false
            self.dropletCancel?.enabled = false
            self.dropletSpinner?.alphaValue = 1
            self.dropletSpinner?.stopAnimation(self)
            self.dropletBar?.stopAnimation(self)
            self.setUIEnabled(true)
            self.dropperLift()
        case .Ready:
            self.droplet?.highlightColor = NSColor.greenColor()
            self.droplet?.borderColor = nil
            self.droplet?.borderSolid = true
            self.dropletLabel?.hidden = true
            self.dropletStart?.hidden = false
            self.dropletClear?.hidden = false
            self.dropletDone?.hidden = true
            self.dropletCancel?.hidden = true
            self.dropletSpinner?.hidden = true
            self.dropletBar?.hidden = true
            self.dropletStart?.enabled = true
            self.dropletClear?.enabled = true
            self.dropletDone?.enabled = false
            self.dropletCancel?.enabled = false
            self.dropletSpinner?.alphaValue = 1
            self.dropletSpinner?.stopAnimation(self)
            self.dropletBar?.stopAnimation(self)
            self.setUIEnabled(true)
            self.dropperDrop()
        case .Processing:
            self.droplet?.highlightColor = NSColor.redColor()
            self.droplet?.borderColor = nil
            self.droplet?.borderSolid = true
            self.dropletLabel?.hidden = true
            self.dropletStart?.hidden = true
            self.dropletClear?.hidden = true
            self.dropletDone?.hidden = true
            self.dropletCancel?.hidden = false
            self.dropletSpinner?.hidden = true
            self.dropletBar?.hidden = false
            self.dropletStart?.enabled = false
            self.dropletClear?.enabled = false
            self.dropletDone?.enabled = false
            self.dropletCancel?.enabled = true
            self.dropletSpinner?.alphaValue = 1
            self.dropletSpinner?.stopAnimation(self)
            self.dropletBar?.startAnimation(self)
            self.setUIEnabled(false)
            self.dropperDrop()
            
            if let dropletCancel = self.dropletCancel {
                let color = NSColor(hue: 1, saturation: 0.99, brightness: 0.95, alpha: 1)
                let string = NSMutableAttributedString(attributedString: dropletCancel.attributedTitle)
                string.replaceCharactersInRange(NSMakeRange(0, string.length), withString: "Cancel\n ")
                string.removeAttribute(NSForegroundColorAttributeName, range: NSMakeRange(0, string.length))
                string.addAttribute(NSForegroundColorAttributeName, value: color, range: NSMakeRange(0, string.length))
                dropletCancel.attributedTitle = string
            }
        case .Cancelling:
            self.droplet?.highlightColor = NSColor.redColor()
            self.droplet?.borderColor = nil
            self.droplet?.borderSolid = true
            self.dropletLabel?.hidden = true
            self.dropletStart?.hidden = true
            self.dropletClear?.hidden = true
            self.dropletDone?.hidden = true
            self.dropletCancel?.hidden = false
            self.dropletSpinner?.hidden = false
            self.dropletBar?.hidden = true
            self.dropletStart?.enabled = false
            self.dropletClear?.enabled = false
            self.dropletDone?.enabled = false
            self.dropletCancel?.enabled = false
            self.dropletSpinner?.alphaValue = 0.5
            self.dropletSpinner?.startAnimation(self)
            self.dropletBar?.stopAnimation(self)
            self.setUIEnabled(false)
            self.dropperDrop()
            
            if let dropletCancel = self.dropletCancel {
                // using the non-attributed title here results in correct gray-out-on-disable behavior
                dropletCancel.title = "Cancelling...\n "
            }
        case .Done:
            self.droplet?.highlightColor = NSColor.greenColor()
            self.droplet?.borderColor = nil
            self.droplet?.borderSolid = false
            self.dropletLabel?.hidden = true
            self.dropletStart?.hidden = true
            self.dropletClear?.hidden = true
            self.dropletDone?.hidden = false
            self.dropletCancel?.hidden = true
            self.dropletSpinner?.hidden = true
            self.dropletBar?.hidden = true
            self.dropletStart?.enabled = false
            self.dropletClear?.enabled = false
            self.dropletDone?.enabled = true
            self.dropletCancel?.enabled = false
            self.dropletSpinner?.alphaValue = 1
            self.dropletSpinner?.stopAnimation(self)
            self.dropletBar?.stopAnimation(self)
            self.setUIEnabled(true)
            self.dropperDrop()
        }
    }
}
