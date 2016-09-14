//
//  ViewController.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-8-25.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

import Cocoa
import QuartzCore

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, DraggityDropDestination {
    enum FileStatus: Int {
        case None = 0
        case Ready
        case Processing
        case Done
        case Cancelled
        case Error
        
        var finished : Bool {
            switch self {
            case .None: return false
            case .Ready: return false
            case .Processing: return false
            case .Done: return true
            case .Cancelled: return true
            case .Error: return true
            }
        }
    }
    
    enum ProcessorError: Int {
        case None = 0
        case InvalidSize
        case InvalidFiletype
        case InvalidInput
        case InvalidOutput
        case NotEnoughSpace
        case ProcessingFailed
        case NoWritePermission
        case Other
        
        var description : String {
            switch self {
            case .None: return "None"
            case .InvalidSize: return "Invalid size"
            case .InvalidFiletype: return "Invalid filetype"
            case .InvalidInput: return "Invalid input"
            case .InvalidOutput: return "Invalid output"
            case .NotEnoughSpace: return "Not enough space"
            case .ProcessingFailed: return "Processing failed"
            case .NoWritePermission: return "No write permission"
            case .Other: return "Other"
            }
        }
    }
    
    enum ProcessingStatus: Int {
        case None = 0
        case ShouldStop
        case DidStop
    }
    
    enum DropletMode: Int {
        case Default
        case Hover
        case Ready
        case Processing
        case Cancelling
        case Done
    }
    
    var allowedTypes: [String] {
        get {
            // get the list of allowed UTIs from the Info.plist file
            if let documentTypes = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleDocumentTypes") as? [NSDictionary] {
                for dictionary in documentTypes {
                    if let name = dictionary["CFBundleTypeName"] as? String, let types = dictionary["LSItemContentTypes"] as? [String] {
                        if name == "Image" {
                            return types
                        }
                    }
                }
            }
            
            return []
        }
    }
    
    // outlets
    @IBOutlet weak var droplet: DropletView?
    @IBOutlet weak var dropletContainer: NSView?
    @IBOutlet weak var dropletShadow: ShadowView?
    @IBOutlet weak var dropletStart: NSButton?
    @IBOutlet weak var dropletClear: NSButton?
    @IBOutlet weak var dropletLabel: NSTextField?
    @IBOutlet weak var dropletCancel: NSButton?
    @IBOutlet weak var dropletDone: NSButton?
    @IBOutlet weak var dropletSpinner: NSProgressIndicator?
    @IBOutlet weak var dropletBar: NSProgressIndicator?
    @IBOutlet weak var settingsArea: NSView?
    @IBOutlet weak var tasksArea: NSView?
    @IBOutlet weak var resolutionH: NSTextField?
    @IBOutlet weak var resolutionV: NSTextField?
    @IBOutlet weak var resolutionSync: NSButton?
    @IBOutlet weak var gradientButton: CustomButton?
    @IBOutlet weak var colorButton: CustomButton?
    @IBOutlet weak var colorPicker: NSSegmentedControl?
    @IBOutlet weak var outputButton: NSButton?
    @IBOutlet weak var outputButtonDropper: DragDroppableView?
    @IBOutlet weak var finderButton: NSButton?
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var tableViewDropper: DragDroppableView?
    @IBOutlet weak var settings: NSMatrix?
    @IBOutlet weak var outputDirectoryLabel: NSTextField?
    
    weak var openPanel: NSOpenPanel?
    
    // parameters
    var outputDirectory: NSString? //TODO: change back to URL as per Swift errors
    var outputURL: NSURL? //AB: solely for security scoping shenanigans -- replace above later
    var customColor: NSColor {
        get {
            if
                let data = NSUserDefaults.standardUserDefaults().dataForKey(kDefaultsColor),
                let color = NSUnarchiver.unarchiveObjectWithData(data) as? NSColor
            {
                return color
            }
            else {
                return NSColor.whiteColor()
            }
        }
    }
    var resolution: NSSize
    
    // UI state
    var toggle = false
    var dropperAnimation: (timer: NSTimer, startTime: Double, duration: Double, timingFunction: ((duration: Double, t: Double) -> Double), actionFunction: ((t: Double) -> Void))?
    
    // data state
    var files: [(path:String,status:FileStatus,error:ProcessorError?)] = []
    var processing: Bool = false
    var shouldStopProcessingFlag: Bool = false
    var queue: dispatch_queue_t

    required init?(coder: NSCoder) {
        // first, see if we have an existing security-scoped bookmark
        if let bookmark = NSUserDefaults.standardUserDefaults().objectForKey(kDefaultsLastUsedDirectory) as? NSData {
            do {
                var stale: ObjCBool = false
                let url = try NSURL(byResolvingBookmarkData: bookmark, options: .WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &stale)
                
                if stale {
                    NSLog("Warning: security scoped bookmark was stale")
                }
                else {
                    url.startAccessingSecurityScopedResource()
                    
                    self.outputDirectory = url.path
                    self.outputURL = url
                }
            }
            catch {
                NSLog("Warning: security scoped bookmark could not be resolved")
            }
        }
        
        if self.outputDirectory == nil {
            // initialize output directory with default document directory
            let paths = NSSearchPathForDirectoriesInDomains(.PicturesDirectory, .UserDomainMask, true)
            if let output = paths.first {
                if var outputResolvedPath: NSString = (NSURL(fileURLWithPath: output).path as NSString?)?.stringByResolvingSymlinksInPath {
                    let destinationName = "Backgroundifier"
                    outputResolvedPath = outputResolvedPath.stringByAppendingPathComponent(destinationName)
                    
                    self.outputDirectory = outputResolvedPath
                }
            }
        }
        
        // placeholder value
        // TODO: hardcoded, not good — validate!
        self.resolution = NSMakeSize(10, 10)
        
        self.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
        super.init(coder: coder)
    }
    
    ///////////////////////////
    // MARK: - View Lifecycle -
    ///////////////////////////
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.droplet?.delegate = self
        self.outputButtonDropper?.delegate = self
        self.tableViewDropper?.delegate = self
        
        if let dropletStart = self.dropletStart {
            let color = NSColor(hue: CGFloat(112.0/360.0), saturation: 1, brightness: 0.59, alpha: 1)
            let colorTitle = NSMutableAttributedString(attributedString: dropletStart.attributedTitle)
            let titleRange = NSMakeRange(0, colorTitle.length)
            colorTitle.addAttribute(NSForegroundColorAttributeName, value: color, range: titleRange)
            dropletStart.attributedTitle = colorTitle
        }
        
        if let dropletClear = self.dropletClear {
            let color = NSColor(hue: 1, saturation: 0.99, brightness: 0.95, alpha: 1)
            let colorTitle = NSMutableAttributedString(attributedString: dropletClear.attributedTitle)
            let titleRange = NSMakeRange(0, colorTitle.length)
            colorTitle.addAttribute(NSForegroundColorAttributeName, value: color, range: titleRange)
            dropletClear.attributedTitle = colorTitle
        }
        
        if let dropletCancel = self.dropletCancel {
            let color = NSColor(hue: 1, saturation: 0.99, brightness: 0.95, alpha: 1)
            let colorTitle = NSMutableAttributedString(attributedString: dropletCancel.attributedTitle)
            let titleRange = NSMakeRange(0, colorTitle.length)
            colorTitle.addAttribute(NSForegroundColorAttributeName, value: color, range: titleRange)
            dropletCancel.attributedTitle = colorTitle
        }
        
        if let dropletDone = self.dropletDone {
            let color = NSColor(hue: CGFloat(112.0/360.0), saturation: 1, brightness: 0.59, alpha: 1)
            let colorTitle = NSMutableAttributedString(attributedString: dropletDone.attributedTitle)
            let titleRange = NSMakeRange(0, colorTitle.length)
            colorTitle.addAttribute(NSForegroundColorAttributeName, value: color, range: titleRange)
            dropletDone.attributedTitle = colorTitle
        }
        
        // black square w/o this incantation; whatever
        if let container = self.dropletContainer {
            container.scaleUnitSquareToSize(NSMakeSize(0.5, 0.5))
        }
        
        if let cell: NSCell = self.colorButton?.cell {
            (cell as? CustomButtonCell)?.top = false
        }
        
        // initialize user default bindings
        if let settings = self.settings {
            for cell in settings.cells {
                if let cell = cell as? NSButtonCell, let identifier = cell.identifier {
                    cell.state = (NSUserDefaults.standardUserDefaults().boolForKey(identifier) ? NSOnState : NSOffState)
                }
            }
        }
        
        if let pathString = self.outputDirectory {
            outputButton?.title = pathString as String
        }
        else {
            outputButton?.title = "Please select an output directory"
        }
        
        let _ = NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsAuto)
        self.colorPicker?.selectSegmentWithTag(NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsAuto) ? 0 : 1)
        
        self.updateColorPickerAppearance()
        self.syncResolution(nil)
        self.setDropletMode(self.dropletNonHoverMode())
        self.selectBlurOrColor(NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsBlurred))
        self.varyDropper(0)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // maybe not the best place for window setup, but it works
        self.view.window?.movableByWindowBackground = true
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.title = ""
        
        self.openPanel(self.toggle, animated: false)
    }
    
    // close on Cmd-W
    override func keyDown(theEvent: NSEvent) {
        if theEvent.characters?.uppercaseString == "W" && theEvent.modifierFlags.contains(NSCommandKeyMask) {
            self.view.window?.performClose(self)
        }
    }
    
    //////////////////////////////////////////////
    // MARK: - Table View Data Source / Delegate -
    //////////////////////////////////////////////
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return files.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if let tableColumn = tableColumn {
            if tableColumn.identifier == "Name" {
                let path = self.files[row].path
                return path
            }
            else if tableColumn.identifier == "Progress" {
                switch self.files[row].status {
                case .Ready:
                    return ""
                case .Processing:
                    return "Processing"
                case .Done:
                    return "Done"
                case .Error:
                    if let error = self.files[row].error {
                        return "Error: \(error.description)"
                    }
                    else {
                        return "Unknown error"
                    }
                case .Cancelled:
                    return "Cancelled"
                default:
                    return nil
                }
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
    }
    
    func tableView(tableView: NSTableView, shouldEditTableColumn tableColumn: NSTableColumn?, row: Int) -> Bool {
        return false
    }
}
