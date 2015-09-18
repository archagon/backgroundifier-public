//
//  ViewController_Data.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-9-14.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

extension ViewController {
    func createOutputDirectory() -> Bool {
        var success = false
        
        if let outputDirectory = outputDirectory {
            var error: NSError?
            NSFileManager.defaultManager().createDirectoryAtPath(outputDirectory, withIntermediateDirectories: true, attributes: nil, error: &error)
            
            // found/created output directory!
            if error == nil {
                success = true
            }
        }
        
        return success
    }
    
    func process() {
        if self.processing {
            return
        }
        
        let directoryCreated = self.createOutputDirectory()
        if !directoryCreated {
            return
        }
        
        // calculate number of simultaneous threads
        if let widthString = self.resolutionH?.stringValue, heightString = self.resolutionV?.stringValue {
            let width = CGFloat((widthString as NSString).doubleValue)
            let height = CGFloat((heightString as NSString).doubleValue)
            
            // set limits on memory and CPU in case system reports something crazy
            let megabytesMemory = min((Double(NSProcessInfo.processInfo().physicalMemory) / 1024.0) / 1024.0, 32 * 1024)
            let cores = min(NSProcessInfo.processInfo().processorCount, 16)
            let activeCores = min(NSProcessInfo.processInfo().activeProcessorCount, 16)
            
            // estimate of the memory required for each processed image
            let megabytesPerPicture = Double(width * height)
                * 4.0       // bytes per pixel
                / 1024.0    // kilobytes
                / 1024.0    // megabytes
                * 1.5       // safety factor
                * 4         // ~number of image-sized allocations during processing
            
            // don't lock up all cores/memory
            let minCores = 1
            let maxCores = max(minCores, cores / 2)
            let maxMegabytesMemory = megabytesMemory / 4
            
            var finalCores = maxCores
            for cores in minCores...maxCores {
                let totalMemory = Double(cores + 1) * megabytesPerPicture
                
                if totalMemory > maxMegabytesMemory {
                    finalCores = cores
                    break
                }
            }
            
            self.shouldStopProcessingFlag = false
            self.processing = true
            
            let files = self.files
            
            let overwrite = NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsOverwrite)
            let auto = NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsAuto)
            let blur = NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsBlurred)
            let shadowAlpha = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsShadowAlpha))
            let blurConstant = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsBlurConstant))
            let shadowConstant = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsShadowConstant))
            let minimumEdgeGapToHeightRatio = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsMinimumEdgeGapToHeightRatio))
            let targetBackgroundScale = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsTargetBackgroundScale))
            let maximumStretchScale = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsMaximumStretchScale))
            let customColor = self.customColor
            
            let outputDirectory = self.outputDirectory
            let allowedTypes = self.allowedTypes
            
            var toDo: Int = files.count //only accessed on the main thread
            var doneSet: [Int:Bool] = [:] //only accessed on the main thread
            
            var finished: [Bool] = [] //only accessed on the main thread
            for core in 0..<finalCores {
                finished.append(false)
            }
            
            for core in 0..<finalCores {
                dispatch_async(self.queue, { () -> Void in
                    // cancelled flag; cancel if found to be true
                    var cancelled = false
                    
                    // sub-function 1: commit the file results to the main thread and update the table
                    let commit = { (index: Int, output: NSURL?, status: FileStatus, error: ProcessorError?) -> Void in
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            if error != nil && error != ProcessorError.None {
                                self.files[index].status = .Error
                                self.files[index].error = error
                            }
                            else {
                                self.files[index].status = status
                                
                                if status == .Done {
                                    // TODO: we can set the desktop background here
                                }
                            }
                            
                            if status.finished {
                                doneSet[index] = true
                            }
                            
                            self.tableView?.reloadDataForRowIndexes(NSIndexSet(index: index), columnIndexes: NSIndexSet(indexesInRange: NSMakeRange(1, 1)))
                            self.tableView?.scrollRowToVisible(index)
                            self.dropletBar?.doubleValue = (Double(doneSet.count) / Double(toDo)) * 100
                        });
                    }
                    
                    // sub-function 2: actually process the image and save the results
                    let process = { (image: NSImage, filename: String, outputURL: NSURL) -> ProcessorError in
                        var returnValue: ProcessorError = .None
                        
                        autoreleasepool {
                            if let imageRep = processImage(image, NSMakeSize(width, height), blur, (auto ? nil : customColor), blurConstant, shadowConstant, minimumEdgeGapToHeightRatio, targetBackgroundScale, maximumStretchScale, shadowAlpha) {
                                if let data = imageRep.representationUsingType(NSBitmapImageFileType.NSJPEGFileType, properties: [NSImageCompressionFactor:0.75]) {
                                    var newOutputURL = outputURL.URLByAppendingPathComponent(filename)
                                    if let originalOutputPath = newOutputURL.path {
                                        let leftPath = originalOutputPath.stringByDeletingLastPathComponent
                                        var filename = originalOutputPath.lastPathComponent.stringByDeletingPathExtension
                                        let ext = "jpg"
                                        
                                        if var outputPath = leftPath.stringByAppendingPathComponent("\(filename)").stringByAppendingPathExtension(ext) {
                                            // check for existing files with the same name
                                            if !overwrite {
                                                var i = 0
                                                let arbitrarySearchLimit = 10000
                                                while (i < arbitrarySearchLimit) {
                                                    let filenameAddition = (i == 0 ? "" : " (\(i))")
                                                    
                                                    if let newOutputPath = leftPath.stringByAppendingPathComponent("\(filename)\(filenameAddition)").stringByAppendingPathExtension(ext) {
                                                        if !NSFileManager.defaultManager().fileExistsAtPath(newOutputPath) {
                                                            outputPath = newOutputPath
                                                            break
                                                        }
                                                    }
                                                    
                                                    i += 1
                                                }
                                            }
                                            
                                            var error: NSError?
                                            let fileWritten = data.writeToFile(outputPath, options: NSDataWritingOptions.DataWritingAtomic, error: &error)
                                            
                                            if error != nil {
                                                returnValue = .ProcessingFailed
                                            }
                                            else {
                                                returnValue = .None
                                            }
                                        }
                                        else {
                                            returnValue = .InvalidOutput
                                        }
                                    }
                                    else {
                                        returnValue = .InvalidOutput
                                    }
                                }
                                else {
                                    returnValue = .ProcessingFailed
                                }
                            }
                            else {
                                returnValue = .ProcessingFailed
                            }
                        }
                        
                        return returnValue
                    }
                    
                    for (i, element) in enumerate(files) {
                        if (self.shouldStopProcessingFlag) {
                            cancelled = true //cancelled can only be toggled ON
                        }
                        
                        // TODO: should be done better — pull from remaining files instead of pre-dividing input
                        if (i % finalCores != core) {
                            continue
                        }
                        
                        if (cancelled) {
                            commit(i, nil, .Cancelled, nil)
                            continue
                        }
                        
                        if let elementURL = NSURL(fileURLWithPath: element.path) {
                            if let outputPath = outputDirectory, let outputURL = NSURL(fileURLWithPath: outputPath) {
                                commit(i, outputURL, .Processing, nil)
                                
                                var errorCode = ProcessorError.None
                                
                                var error: NSError?
                                var type: AnyObject?
                                let gotResourceValue = elementURL.getResourceValue(&type, forKey: NSURLTypeIdentifierKey, error: &error)
                                if gotResourceValue {
                                    if let type = type as? String {
                                        // TODO: async read?
                                        if let data = NSData(contentsOfURL: elementURL) {
                                            if let image = NSImage(data: data) {
                                                var foundConformingType = false
                                                for allowedType in allowedTypes {
                                                    if NSWorkspace.sharedWorkspace().type(type, conformsToType: allowedType as String) {
                                                        foundConformingType = true
                                                        break
                                                    }
                                                }
                                                
                                                if foundConformingType {
                                                    if let filename = elementURL.lastPathComponent {
                                                        errorCode = process(image, filename, outputURL)
                                                    }
                                                    else {
                                                        errorCode = .InvalidInput
                                                    }
                                                }
                                                else {
                                                    errorCode = .InvalidFiletype
                                                }
                                            }
                                            else {
                                                // could not get image from data
                                                errorCode = .InvalidInput
                                            }
                                        }
                                        else {
                                            // could not get data from file
                                            errorCode = .InvalidInput
                                        }
                                    }
                                    else {
                                        // type is not string? weird
                                        errorCode = .Other
                                    }
                                }
                                else {
                                    if let error = error {
                                        if error.code == NSFileReadNoSuchFileError {
                                            // file not found often appears here
                                            errorCode = .InvalidInput
                                        }
                                        else {
                                            errorCode = .Other
                                        }
                                    }
                                    else {
                                        errorCode = .Other
                                    }
                                }
                                
                                commit(i, outputURL, .Done, errorCode)
                            }
                            else {
                                commit(i, nil, .Error, .InvalidOutput)
                            }
                        }
                        else {
                            commit(i, nil, .Error, .InvalidInput)
                        }
                    }
                    
                    // finalize
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        finished[core] = true
                        
                        let allDone = finished.reduce(true, combine: { (accumulated: Bool, finished: Bool) -> Bool in
                            accumulated && finished
                        })
                        
                        if allDone {
                            self.processing = false
                            self.setDropletMode(self.dropletNonHoverMode())
                            self.dropperBounce()
                            NSApp.requestUserAttention(NSRequestUserAttentionType.InformationalRequest)
                        }
                    });
                    
                })
            }
        }
    }
    
    func validateResolution(dimension: CGFloat) -> CGFloat {
        if dimension < 10 {
            return 10
        }
        else if dimension > 9000 {
            return 9000
        }
        else {
            return dimension
        }
    }
    
    func validateResolutionString(string: String) -> (text: String, value: CGFloat) {
        let value = CGFloat((string as NSString).doubleValue)
        return ("\(Int(self.validateResolution(value)))", value)
    }
    
    func colorPicked(panel: NSColorPanel) {
        NSUserDefaults.standardUserDefaults().setObject(NSArchiver.archivedDataWithRootObject(panel.color), forKey: kDefaultsColor)
        NSUserDefaults.standardUserDefaults().synchronize()
        self.updateColorPickerAppearance()
    }
    
    func updateOutputDirectory(directory: NSURL) {
        self.outputDirectory  = directory.path
        
        if let pathString = self.outputDirectory {
            outputButton?.title = pathString
        }
        else {
            outputButton?.title = "Please select an output directory"
        }
    }
}
