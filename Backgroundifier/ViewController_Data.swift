//
//  ViewController_Data.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-9-14.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

extension ViewController {
    func createOutputDirectory() -> Bool {
        var success = true
        
        if let outputDirectory = outputDirectory {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(outputDirectory as String, withIntermediateDirectories: true, attributes:nil)
            }
            catch {
                success = false
            }
        }
        
        return success
    }
    
    func process() {
        // AB: might not really belong here, but process() is the only place where the output dir is actually used
        self.openPanel?.close()
        self.openPanel = nil
        
        if self.processing {
            return
        }
        
        let directoryCreated = self.createOutputDirectory()
        if !directoryCreated {
            return
        }
        
        // calculate number of simultaneous threads
        if
            let widthString = self.resolutionH?.stringValue,
            let heightString = self.resolutionV?.stringValue
        {
            let width = CGFloat((widthString as NSString).doubleValue)
            let height = CGFloat((heightString as NSString).doubleValue)
            
            // set limits on memory and CPU in case system reports something crazy
            let megabytesMemory = min((Double(NSProcessInfo.processInfo().physicalMemory) / 1024.0) / 1024.0, 32 * 1024)
            let cores = min(NSProcessInfo.processInfo().processorCount, 16)
            //let activeCores = min(NSProcessInfo.processInfo().activeProcessorCount, 16)
            
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
            let maximumBlurRadius = CGFloat(NSUserDefaults.standardUserDefaults().doubleForKey(kDefaultsMaximumBlurRadius))
            let customColor = self.customColor
            
            let outputDirectory = self.outputDirectory
            let allowedTypes = self.allowedTypes
            
            let toDo: Int = files.count //only accessed on the main thread
            var doneSet: [Int:Bool] = [:] //only accessed on the main thread
            
            var finished: [Bool] = [] //only accessed on the main thread
            for _ in 0..<finalCores {
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
                            processing: do {
                                // process image
                                guard let imageRep = processImage(image, resolution: NSMakeSize(width, height), blur: blur, color: (auto ? nil : customColor), blurConstant: blurConstant, shadowConstant: shadowConstant, minimumEdgeGapToHeightRatio: minimumEdgeGapToHeightRatio, targetBackgroundScale: targetBackgroundScale, maximumStretchScale: maximumStretchScale, maximumBlurRadius: maximumBlurRadius, shadowAlpha: shadowAlpha) else {
                                    returnValue = .ProcessingFailed
                                    break processing
                                }
                                
                                // convert image data to compressed image data
                                guard let data = imageRep.representationUsingType(NSBitmapImageFileType.JPEG, properties: [NSImageCompressionFactor:0.75]) else {
                                    returnValue = .ProcessingFailed
                                    break processing
                                }
                                
                                let newOutputURL = outputURL.URLByAppendingPathComponent(filename)
                                
                                // get output dir path
                                guard let originalOutputPath = newOutputURL?.path as NSString? else {
                                    returnValue = .InvalidOutput
                                    break processing
                                }
                                
                                let leftPath: NSString = originalOutputPath.stringByDeletingLastPathComponent
                                let filename: NSString = (originalOutputPath.lastPathComponent as NSString).stringByDeletingPathExtension
                                let ext = "jpg"
                                
                                // get full output path (w/file)
                                guard var outputPath = (leftPath.stringByAppendingPathComponent("\(filename)") as NSString).stringByAppendingPathExtension(ext) else {
                                    returnValue = .InvalidOutput
                                    break processing
                                }
                                
                                // check for existing files with the same name
                                if !overwrite {
                                    var i = 0
                                    let arbitrarySearchLimit = 10000
                                    while (i < arbitrarySearchLimit) {
                                        let filenameAddition = (i == 0 ? "" : " (\(i))")
                                        
                                        if let newOutputPath = (leftPath.stringByAppendingPathComponent("\(filename)\(filenameAddition)") as NSString).stringByAppendingPathExtension(ext) {
                                            if !NSFileManager.defaultManager().fileExistsAtPath(newOutputPath) {
                                                outputPath = newOutputPath
                                                break
                                            }
                                        }
                                        
                                        i += 1
                                    }
                                }
                                
                                // wriiiiite
                                do {
                                    let dataURL = NSURL(fileURLWithPath: outputPath)
                                    try data.writeToURL(dataURL, options: NSDataWritingOptions.DataWritingAtomic)
                                    returnValue = .None
                                }
                                catch NSCocoaError.FileWriteNoPermissionError {
                                    returnValue = .NoWritePermission
                                }
                                catch {
                                    returnValue = .ProcessingFailed
                                }
                            }
                        }
                        
                        return returnValue
                    }

                    for (i, element) in files.enumerate() {
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

                        conversion: do {
                            // create file url for image
                            guard let elementURL: NSURL = NSURL(fileURLWithPath: element.path) else {
                                commit(i, nil, .Error, .InvalidInput)
                                break conversion
                            }
                            
                            // create output path and url
                            guard let outputPath = outputDirectory, let outputURL: NSURL = NSURL(fileURLWithPath: outputPath as String) else {
                                commit(i, nil, .Error, .InvalidOutput)
                                break conversion
                            }
                            
                            // now we're actually processing
                            commit(i, outputURL, .Processing, nil)
                            
                            var errorCode = ProcessorError.None
                            
                            processing: do {
                                var objType: AnyObject?
                                
                                // get file url type
                                do { try elementURL.getResourceValue(&objType, forKey: NSURLTypeIdentifierKey) }
                                catch let error as NSError {
                                    if error.code == NSFileReadNoSuchFileError {
                                        // file not found often appears here
                                        errorCode = .InvalidInput
                                    }
                                    else {
                                        errorCode = .Other
                                    }
                                    break processing
                                }
                                
                                // ensure it's a string
                                guard let type = objType as? String else {
                                    // type is not string? weird
                                    errorCode = .Other
                                    break processing
                                }
                                
                                // ensure we have an allowed filetype
                                var foundConformingType = false
                                for allowedType in allowedTypes {
                                    if NSWorkspace.sharedWorkspace().type(type, conformsToType: allowedType as String) {
                                        foundConformingType = true
                                        break
                                    }
                                }
                                if !foundConformingType {
                                    errorCode = .InvalidFiletype
                                    break processing
                                }
                                
                                // get actual image data
                                // TODO: async read?
                                guard let data = NSData(contentsOfURL: elementURL) else {
                                    // could not get data from file
                                    errorCode = .InvalidInput
                                    break processing
                                }
                                
                                // create an image from that data
                                guard let image = NSImage(data: data) else {
                                    // could not get image from data
                                    errorCode = .InvalidInput
                                    break processing
                                }
                                
                                // get the filename
                                guard let filename = elementURL.lastPathComponent else {
                                    errorCode = .InvalidInput
                                    break processing
                                }
                                
                                errorCode = process(image, filename, outputURL)
                            }
                            
                            commit(i, outputURL, .Done, errorCode)
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
                    })
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
        // duplicate directory? don't do anything!
        if let aURL = self.outputURL {
            if aURL == directory {
                return
            }
        }
        
        securityScoping: do {
            if let oldURL = self.outputURL {
                oldURL.stopAccessingSecurityScopedResource()
            }
            
            let newSecurityScopedBookmark = try directory.bookmarkDataWithOptions(.WithSecurityScope, includingResourceValuesForKeys: nil, relativeToURL: nil)
            
            NSUserDefaults.standardUserDefaults().setObject(newSecurityScopedBookmark, forKey: kDefaultsLastUsedDirectory)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
        catch {
            NSLog("Warning: could not save security scoped bookmark")
        }
        
        self.outputDirectory = directory.path
        self.outputURL = directory
        
        if let pathString = self.outputDirectory {
            outputButton?.title = pathString as String
        }
        else {
            outputButton?.title = "Please select an output directory"
        }
    }
}
