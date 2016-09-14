//
//  Main.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-8-27.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

import Foundation

// AB: we have to change this manually, unfortunately
let versionNumber = "1.0.5 (15)"

let kDefaultsLastUsedDirectory = "lastUsedDirectory"
let kDefaultsRecursive = "recursive"
let kDefaultsOverwrite = "overwrite"
let kDefaultsOutput = "output"
let kDefaultsBlurred = "blurred"
let kDefaultsAuto = "auto"
let kDefaultsColor = "color"
let kDefaultsBlurConstant = "blurConstant"
let kDefaultsShadowConstant = "shadowConstant"
let kDefaultsMinimumEdgeGapToHeightRatio = "minimumEdgeGapToHeightRatio"
let kDefaultsTargetBackgroundScale = "targetBackgroundScale"
let kDefaultsMaximumStretchScale = "maximumStretchScale"
let kDefaultsShadowAlpha = "shadowAlpha"
let kDefaultsMaximumBlurRadius = "maximumBlurRadius"

let defaultFloatValues: [String:Double] = [
    kDefaultsBlurConstant:(200.0 / 2100.0), // magic number based on what looks good at my laptop resolution
    kDefaultsShadowConstant:(78.0 / 2100.0), // magic number based on what looks good at my laptop resolution
    kDefaultsMinimumEdgeGapToHeightRatio:0.125,
    kDefaultsTargetBackgroundScale:1.5,
    kDefaultsMaximumStretchScale:10000, // functionally infinity
    kDefaultsShadowAlpha:0.5,
    kDefaultsMaximumBlurRadius:250 // at about 270-280 on my system, the background image suddenly becomes white
]

let defaultValueForFloatKey = { (name: String) -> Double in
    if let returnValue = defaultFloatValues[name] {
        return returnValue
    }
    else {
        return 0
    }
}

let launchApp = { () -> Int32 in
    let isInCommandLineMode: Bool = {
        if let info = NSBundle.mainBundle().infoDictionary {
            if info.count > 0 {
                return false
            }
            else {
                return true
            }
        }
        else {
            return true
        }
    }()
    
    if isInCommandLineMode {
        return EX_USAGE
    }
    
    let defaults: [String:AnyObject] = [
        kDefaultsRecursive:true,
        kDefaultsOverwrite:false,
        kDefaultsBlurred:true,
        kDefaultsAuto:true,
        kDefaultsColor:NSArchiver.archivedDataWithRootObject(NSColor.blueColor()),
        kDefaultsBlurConstant:defaultValueForFloatKey(kDefaultsBlurConstant),
        kDefaultsShadowConstant:defaultValueForFloatKey(kDefaultsShadowConstant),
        kDefaultsMinimumEdgeGapToHeightRatio:defaultValueForFloatKey(kDefaultsMinimumEdgeGapToHeightRatio),
        kDefaultsTargetBackgroundScale:defaultValueForFloatKey(kDefaultsTargetBackgroundScale),
        kDefaultsMaximumStretchScale:defaultValueForFloatKey(kDefaultsMaximumStretchScale),
        kDefaultsShadowAlpha:defaultValueForFloatKey(kDefaultsShadowAlpha),
        kDefaultsMaximumBlurRadius:defaultValueForFloatKey(kDefaultsMaximumBlurRadius)
    ]
    NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
    
    return NSApplicationMain(Process.argc, Process.unsafeArgv)
}

class FilteredUsageCommandLine: CommandLine {
    var prohibitedOptions: [Option] = []
    
    func printUsage<TargetStream: OutputStreamType>(inout to: TargetStream, startingWithNewline: Bool) {
        let format = formatOutput != nil ? formatOutput! : defaultFormat
        
        if startingWithNewline { print("\n", terminator: "", toStream: &to) }
        print(format("Backgroundifier \(versionNumber)", .About), terminator: "", toStream: &to)
        print(format("Copyright (c) 2015-2016 Alexei Baboulevitch", .About), terminator: "", toStream: &to)
        print(format("http://backgroundifier.archagon.net", .About), terminator: "", toStream: &to)
        print("\n", terminator: "", toStream: &to)
        
        let name = _arguments[0]
        print(format("Usage: \(name) [options]", .About), terminator: "", toStream: &to)
        
        for opt in _options {
            if (prohibitedOptions as NSArray).containsObject(opt) {
                continue
            }
            
            print(format(opt.flagDescription, .OptionFlag), terminator: "", toStream: &to)
            print(format(opt.helpMessage, .OptionHelp), terminator: "", toStream: &to)
        }
        
        print("\n", terminator: "", toStream: &to)
    }
    
    override func printUsage<TargetStream: OutputStreamType>(error: ErrorType, inout to: TargetStream) {
        let format = formatOutput != nil ? formatOutput! : defaultFormat
        
        print("\n", terminator: "", toStream: &to)
        print(format("\(error)", .Error), terminator: "", toStream: &to)
        printUsage(&to, startingWithNewline: false)
    }
    
    override func printUsage<TargetStream: OutputStreamType>(inout to: TargetStream) {
        printUsage(&to, startingWithNewline: true)
    }
}

let attemptCommandLineMode = { () -> Int32 in
    let message = { (message: String) -> Void in
        NSLog("\(message)")
    }
    
    let err = { (message: String) -> Void in
        NSLog("Error: \(message)")
    }
    
    let cli = FilteredUsageCommandLine()
    
    // included by Xcode; can be disabled in scheme editor, but good to handle just in case
    let documentRevisionsDebugMode = StringOption(longFlag: "NSDocumentRevisionsDebugMode", helpMessage: "")
    
    let usage = BoolOption(shortFlag: "u", longFlag: "usage", required: false, helpMessage: "Prints the usage.")
    let help = BoolOption(longFlag: "help", required: false, helpMessage: "Prints the usage.")
    let input = StringOption(shortFlag: "i", longFlag: "input", required: false, helpMessage: "Path to the input file. (If you're running this from the sandbox, input can only be retrieved from your Pictures directory.)")
    let output = StringOption(shortFlag: "o", longFlag: "output", required: false, helpMessage: "Path to the output file. (If you're running this from the sandbox, output can only be saved to your Pictures directory.)")
    let width = IntOption(shortFlag: "w", longFlag: "width", required: false, helpMessage: "Output image width.")
    let height = IntOption(shortFlag: "h", longFlag: "height", required: false, helpMessage: "Output image height.")
    let color = StringOption(shortFlag: "c", longFlag: "color", required: false, helpMessage: "Use a color for the background instead of the default blur. Specify a color in hex format or 'auto' to automatically pick a background color based on the image.")
    let shadowAlpha = DoubleOption(longFlag: "shadow_alpha", required: false, helpMessage: "Change the shadow alpha. Default value: \(defaultValueForFloatKey(kDefaultsShadowAlpha))")
    let edgeGapRatio = DoubleOption(longFlag: "min_edge_gap_height_ratio", required: false, helpMessage: "Change the ratio of the minimum edge gap to the height of the input. Default value: \(defaultValueForFloatKey(kDefaultsMinimumEdgeGapToHeightRatio))")
    let blurConstant = DoubleOption(longFlag: "blur_constant", required: false, helpMessage: "(Advanced) Change the blur constant. Default value: \(defaultValueForFloatKey(kDefaultsBlurConstant))")
    let shadowConstant = DoubleOption(longFlag: "shadow_constant", required: false, helpMessage: "(Advanced) Change the shadow constant. Default value: \(defaultValueForFloatKey(kDefaultsShadowConstant))")
    let targetBackgroundScale = DoubleOption(longFlag: "target_bg_scale", required: false, helpMessage: "(Advanced) Change the target background scale. Default value: \(defaultValueForFloatKey(kDefaultsTargetBackgroundScale))")
    let maximumStretchScale = DoubleOption(longFlag: "max_stretch_scale", required: false, helpMessage: "(Advanced) Change the max strech scale of the input. Default value: \(defaultValueForFloatKey(kDefaultsMaximumStretchScale))")
    let maximumBlurRadius = DoubleOption(longFlag: "max_blur_radius", required: false, helpMessage: "(Advanced) Change the max blur radius, in case too high of a radius creates a blank background instead of a blurred background. Default value: \(defaultValueForFloatKey(kDefaultsMaximumBlurRadius))")

    let systemOptions: [Option] = [documentRevisionsDebugMode]
    let programOptions: [Option] = [input, output, width, height, color, shadowAlpha, edgeGapRatio, blurConstant, shadowConstant, targetBackgroundScale, maximumStretchScale, maximumBlurRadius, usage, help]
    let options = systemOptions + programOptions
    
    // handled manually so that running w/o arguments (i.e. in GUI mode) doesn't print an error
    let requiredOptions = [input, output, width, height]
    
    for option in systemOptions {
        cli.prohibitedOptions.append(option)
    }

    cli.addOptions(options)

    do {
        try cli.parse()
        
        var atLeastOneOptionFound = { () -> Bool in
            var returnValue = false
            
            for option in programOptions {
                if option.wasSet {
                    returnValue = true
                    break
                }
            }
            
            return returnValue
        }()
        
        if !atLeastOneOptionFound {
            // app mode
            
            let appReturn = launchApp()
            if appReturn == EX_USAGE {
                cli.printUsage()
            }
            return appReturn
        }
        else {
            // command line mode
        
            if usage.value || help.value {
                cli.printUsage()
                return EX_USAGE
            }
            
            // TODO: process directly from requiredOptions array
            if let input = input.value, let output = output.value, let width = width.value, let height = height.value {
                var shouldUseColor = false
                var colorObj: NSColor? = nil
                
                // check color
                if var colorValue = color.value {
                    shouldUseColor = true
                    
                    if colorValue == "auto" {
                        // no need to set color
                        colorObj = nil
                    }
                    else {
                        // TODO: handle '#'
                        //color = color.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                        //let hash: Character = "#"
                        //if color.characters.first == hash {
                        //}
                        
                        // try to parse as hex
                        var scanner = NSScanner(string: colorValue)
                        var result: UInt32 = 0
                        let converted = scanner.scanHexInt(&result)
                        
                        if converted {
                            let b = (result & 0x0000ff) >> (8 * 0)
                            let g = (result & 0x00ff00) >> (8 * 1)
                            let r = (result & 0xff0000) >> (8 * 2)
                            
                            let rf = CGFloat(r) / CGFloat(255)
                            let gf = CGFloat(g) / CGFloat(255)
                            let bf = CGFloat(b) / CGFloat(255)
                            
                            colorObj = NSColor(red: rf, green: gf, blue: bf, alpha: 1)
                        }
                        else {
                            let error = CommandLine.ParseError.InvalidValueForOption(color, [colorValue])
                            cli.printUsage(error)
                            
                            return EX_USAGE
                        }
                    }
                }

                let shadowAlphaValue = (shadowAlpha.value != nil ? shadowAlpha.value! : defaultValueForFloatKey(kDefaultsShadowAlpha))
                let edgeGapRatioValue = (edgeGapRatio.value != nil ? edgeGapRatio.value! : defaultValueForFloatKey(kDefaultsMinimumEdgeGapToHeightRatio))
                let blurConstantValue = (blurConstant.value != nil ? blurConstant.value! : defaultValueForFloatKey(kDefaultsBlurConstant))
                let shadowConstantValue = (shadowConstant.value != nil ? shadowConstant.value! : defaultValueForFloatKey(kDefaultsShadowConstant))
                let targetBackgroundScaleValue = (targetBackgroundScale.value != nil ? targetBackgroundScale.value! : defaultValueForFloatKey(kDefaultsTargetBackgroundScale))
                let maximumStretchScaleValue = (maximumStretchScale.value != nil ? maximumStretchScale.value! : defaultValueForFloatKey(kDefaultsMaximumStretchScale))
                let maximumBlurRadius = (maximumBlurRadius.value != nil ? maximumBlurRadius.value! : defaultValueForFloatKey(kDefaultsMaximumBlurRadius))
                
                let supportedExt = [
                    "jpeg": NSBitmapImageFileType.JPEG,
                    "jpg": NSBitmapImageFileType.JPEG,
                    "png": NSBitmapImageFileType.PNG,
                    "tiff": NSBitmapImageFileType.TIFF,
                    "tif": NSBitmapImageFileType.TIFF
                ]
                
                let folderPath = (output as NSString).stringByDeletingLastPathComponent
                let originalFilename = (output as NSString).lastPathComponent
                var filename: NSString = (originalFilename as NSString).stringByDeletingPathExtension
                let ext = (originalFilename as NSString).pathExtension
                
                var bitmapFileType: NSBitmapImageFileType!
                if let output = supportedExt[(ext as NSString).lowercaseString] {
                    bitmapFileType = output
                }
                else {
                    err("output filename does not have a supported extension; supported extensions include jpeg, png, and tiff")
                    return EX_DATAERR
                }
                
                do {
                    try NSFileManager.defaultManager().createDirectoryAtPath(folderPath, withIntermediateDirectories: true, attributes:nil)
                }
                catch {
                    err("could not create output directory. If you're running this utility from the sandbox, you can only output to your Pictures directory.")
                    return EX_CANTCREAT
                }
                
                let inputData: NSData!
                if let data = NSData(contentsOfURL: NSURL(fileURLWithPath: input)) {
                    inputData = data
                }
                else {
                    err("could not retrieve data from input. If you're running this utility from the sandbox, you can only get input from your Pictures directory.")
                    return EX_NOINPUT
                }
                
                let image: NSImage!
                if let anImage = NSImage(data: inputData) {
                    image = anImage
                }
                else {
                    err("could not create image from input")
                    return EX_DATAERR
                }
                
                message("Processing \(input)...")
                
                var imageRep: NSBitmapImageRep!
                if var anImageRep: NSBitmapImageRep = processImage(image, resolution: NSMakeSize(CGFloat(width), CGFloat(height)), blur: !shouldUseColor, color: colorObj, blurConstant: CGFloat(blurConstantValue), shadowConstant: CGFloat(shadowConstantValue), minimumEdgeGapToHeightRatio: CGFloat(edgeGapRatioValue), targetBackgroundScale: CGFloat(targetBackgroundScaleValue), maximumStretchScale: CGFloat(maximumStretchScaleValue), maximumBlurRadius: CGFloat(maximumBlurRadius), shadowAlpha: CGFloat(shadowAlphaValue)) {
                    imageRep = anImageRep
                }
                else {
                    err("could not process image")
                    return EX_DATAERR
                }
                
                let properties: [String:AnyObject] = {
                    if bitmapFileType == NSBitmapImageFileType.JPEG {
                        return [ NSImageCompressionFactor: 0.75 ]
                    }
                    else {
                        return [:]
                    }
                }()
                
                var outputData: NSData!
                if let data = imageRep.representationUsingType(bitmapFileType, properties: properties) {
                    outputData = data
                }
                else {
                    err("could not create data from output image")
                    return EX_DATAERR
                }
                
                var outputPath = output

                do {
                    try outputData.writeToFile(outputPath, options: NSDataWritingOptions.DataWritingAtomic)
                    
                    message("Done! Output to \(outputPath)")
                    
                    return EX_OK
                }
                catch {
                    err("could not write output data. If you're running this utility from the sandbox, you can only write output to your Pictures directory.")
                    return EX_CANTCREAT
                }
            }
            else {
                // required options missing
                
                var missingOptions: [Option] = []
                
                for option in requiredOptions {
                    if !option.wasSet {
                        missingOptions.append(option)
                    }
                }
                
                let error = CommandLine.ParseError.MissingRequiredOptions(missingOptions)
                cli.printUsage(error)
                
                return EX_USAGE
            }
        }
    }
    catch {
        let appReturn = launchApp()
        if appReturn == EX_USAGE {
            cli.printUsage()
        }
        return appReturn
    }
}

exit(attemptCommandLineMode())
