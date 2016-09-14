//
//  ViewController_Nib.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-9-14.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

extension ViewController {
    @IBAction func clearTapped(button: NSButton?) {
        self.files = []
        self.tableView?.reloadData()
        self.setDropletMode(self.dropletNonHoverMode())
        
        self.openPanel(false, animated: true)
    }
    
    @IBAction func startTapped(button: NSButton?) {
        self.process()
        self.setDropletMode(self.dropletNonHoverMode())
    }
    
    @IBAction func cancelTapped(button: NSButton?) {
        self.shouldStopProcessingFlag = true
        self.setDropletMode(self.dropletNonHoverMode())
    }
    
    @IBAction func blurTapped(button: NSButton?) {
        self.selectBlurOrColor(true)
    }
    
    @IBAction func colorTapped(button: NSButton?) {
        self.selectBlurOrColor(false)
    }
    
    @IBAction func outputButtonTapped(control: NSButton?) {
        let openPanel = NSOpenPanel()
        openPanel.canCreateDirectories = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Please select the output directory for your converted images."
        
        self.openPanel = openPanel
        openPanel.beginWithCompletionHandler { (result: Int) -> Void in
            if result == NSFileHandlingPanelOKButton {
                if let url = openPanel.URLs.first {
                    self.updateOutputDirectory(url)
                }
            }
            self.openPanel = nil
        }
    }
    
    @IBAction func finderButtonTapped(control: NSButton?) {
        if let outputPath = self.outputDirectory, let outputURL: NSURL = NSURL(fileURLWithPath: outputPath as String) {
            self.createOutputDirectory()
            NSWorkspace.sharedWorkspace().openURL(outputURL)
        }
    }
    
    @IBAction func colorTypePickerChangedValue(control: NSSegmentedControl?) {
        if let control = control {
            self.selectBlurOrColor(false)
            
            if (control.selectedSegment == 1) {
                NSUserDefaults.standardUserDefaults().setBool(false, forKey: kDefaultsAuto)
                
                NSApplication.sharedApplication().orderFrontColorPanel(control)
                let colorPanel: NSColorPanel = NSColorPanel.sharedColorPanel()
                colorPanel.setTarget(self)
                colorPanel.setAction(#selector(ViewController.colorPicked(_:)))
                colorPanel.color = self.customColor
            }
            else {
                NSUserDefaults.standardUserDefaults().setBool(true, forKey: kDefaultsAuto)
            }
            
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    @IBAction func settingChecked(control: NSMatrix?) {
        if let control = control {
            for cell in control.cells {
                let on = (cell.state == NSOnState)
                
                if cell.identifier == kDefaultsRecursive {
                    NSUserDefaults.standardUserDefaults().setBool(on, forKey: kDefaultsRecursive)
                }
                else if cell.identifier == kDefaultsOverwrite {
                    NSUserDefaults.standardUserDefaults().setBool(on, forKey: kDefaultsOverwrite)
                }
                
                NSUserDefaults.standardUserDefaults().synchronize()
            }
        }
    }
    
    @IBAction func syncResolution(control: NSButton?) {
        if let screen = NSScreen.mainScreen() {
            let resolutionScale = screen.backingScaleFactor
            let size = NSMakeSize(screen.frame.size.width * resolutionScale, screen.frame.size.height * resolutionScale)
            
            let newWidth = self.validateResolutionString("\(size.width)")
            let newHeight = self.validateResolutionString("\(size.height)")
            
            self.resolution = NSMakeSize(newWidth.value, newHeight.value)
            self.resolutionH?.stringValue = newWidth.text
            self.resolutionV?.stringValue = newHeight.text
        }
    }
    
    @IBAction func resolutionValueChanged(control: NSTextField?) {
        if let control = control {
            let newValue = self.validateResolutionString(control.stringValue)
            
            if control == self.resolutionH {
                self.resolution.width = newValue.value
                control.stringValue = newValue.text
            }
            else if control == self.resolutionV {
                self.resolution.height = newValue.value
                control.stringValue = newValue.text
            }
        }
    }
    
    func setUIEnabled(enabled: Bool) {
        self.colorButton?.enabled = enabled
        self.gradientButton?.enabled = enabled
        self.resolutionH?.enabled = enabled
        self.resolutionV?.enabled = enabled
        self.resolutionSync?.enabled = enabled
        self.settings?.enabled = enabled
        self.outputButton?.enabled = enabled
        self.colorPicker?.enabled = enabled
        self.droplet?.enabled = enabled
        self.tableViewDropper?.enabled = enabled
        self.outputButtonDropper?.enabled = enabled
        self.outputDirectoryLabel?.alphaValue = (enabled ? 1 : 0.25)
    }
    
    func updateColorPickerAppearance() {
        if let colorPicker = self.colorPicker {
            let image = NSImage(size: NSMakeSize(colorPicker.bounds.size.height * 0.7, colorPicker.bounds.size.height * 0.7))
            
            image.lockFocus()
            self.customColor.setFill()
            var rect = NSMakeRect(0, 0, 0, 0)
            rect.size = image.size
            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            path.fill()
            NSColor.grayColor().setStroke()
            path.lineWidth = 2
            path.setClip()
            path.stroke()
            image.unlockFocus()
            
            colorPicker.setImage(image, forSegment: 1)
        }
    }
    
    func selectBlurOrColor(blur: Bool) {
        NSUserDefaults.standardUserDefaults().setBool(blur, forKey: kDefaultsBlurred)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        let setButtonState = { (button: NSButton?, state: Int) -> Void in
            if let button = button {
                if button.state != state {
                    button.state = state
                }
            }
        }
        
        if blur {
            setButtonState(self.gradientButton, NSOnState)
            setButtonState(self.colorButton, NSOffState)
        }
        else {
            setButtonState(self.gradientButton, NSOffState)
            setButtonState(self.colorButton, NSOnState)
        }
    }
    
    func openPanel(open: Bool, animated: Bool) {
        if let tasksArea = self.tasksArea, settingsArea = self.settingsArea {
            var height: CGFloat!
            
            // TODO: codify title bar height
            if open {
                height = 20 + 8 + settingsArea.frame.size.height + 8 + 8 + tasksArea.frame.size.height + 8
                self.toggle = true
            }
            else {
                height = 20 + 8 + settingsArea.frame.size.height + 8
                self.toggle = false
            }
            
            if let window = self.view.window {
                let frame = NSMakeRect(window.frame.origin.x, window.frame.origin.y - (height - window.frame.size.height), self.view.frame.size.width, height)
                
                if animated {
                    let windowResize: [String:AnyObject] = [ NSViewAnimationTargetKey:window, NSViewAnimationEndFrameKey:NSValue(rect: frame) ]
                    let animations = [ windowResize ]
                    let animation = NSViewAnimation(viewAnimations: animations)
                    animation.animationBlockingMode = NSAnimationBlockingMode.Nonblocking //can run w/other animations concurrently
                    animation.animationCurve = NSAnimationCurve.EaseInOut
                    animation.duration = 0.3
                    animation.startAnimation()
                }
                else {
                    window.setFrame(frame, display: true)
                }
            }
        }
    }
}
