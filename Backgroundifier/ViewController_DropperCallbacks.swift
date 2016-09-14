//
//  ViewController_DropperCallbacks.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-9-14.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

extension ViewController {
    func dropperShouldBegin(dropper: NSView, files: [NSURL]) -> Bool {
        return true
    }
    
    func dropperSupportedFiletypes(dropper: NSView) -> [String] {
        return [ NSURLPboardType ]
    }
    
    func dropperDraggingEntered(dropper: NSView) {
        if let _ = dropper as? DropletView {
            self.setDropletMode(.Hover)
        }
    }
    
    func dropperDraggingExited(dropper: NSView) {
        if let _ = dropper as? DropletView {
            self.setDropletMode(self.dropletNonHoverMode())
        }
    }
    
    func dropperDraggingEnded(dropper: NSView) {
        if let _ = dropper as? DropletView {
            self.setDropletMode(self.dropletNonHoverMode())
        }
    }
    
    func dropperDidGetFiles(dropper: NSView, files: [NSURL]) -> Bool {
        if dropper == self.outputButtonDropper {
            if files.count == 1 {
                let url = files[0]
                
                do {
                    var isDirectory: AnyObject?
                    
                    try url.getResourceValue(&isDirectory, forKey: NSURLIsDirectoryKey)
                    
                    if let isDirectory = isDirectory as? NSNumber {
                        if isDirectory.boolValue {
                            self.updateOutputDirectory(url)
                            return true
                        }
                    }
                }
                catch {
                }
            }
            
            return false
        }
        else if dropper == self.tableViewDropper || dropper == self.droplet || dropper == self.view {
            let checkIfFiletypeIsAllowed = { (url: NSURL?) -> Bool in
                if let aUrl = url {
                    do {
                        var type: AnyObject?
                        
                        try aUrl.getResourceValue(&type, forKey: NSURLTypeIdentifierKey)
                    
                        if let type = type as? String {
                            for allowedType in self.allowedTypes {
                                if NSWorkspace.sharedWorkspace().type(type, conformsToType: allowedType as String) {
                                    return true
                                }
                            }
                        }
                    }
                    catch {
                    }
                }
                
                return false
            }
            
            let fileIsRegularFile = { (url: NSURL?) -> Bool in
                if let url = url {
                    do {
                        var isFile: AnyObject?
                        
                        try url.getResourceValue(&isFile, forKey: NSURLIsRegularFileKey)
                    
                        if let isFile = isFile as? NSNumber {
                            return isFile.boolValue
                        }
                    }
                    catch {
                    }
                }
                
                return false
            }
            
            let recursiveSearch = { (url: NSURL?) -> [NSURL] in
                if let aUrl = url {
                    if fileIsRegularFile(aUrl) {
                        if checkIfFiletypeIsAllowed(aUrl) {
                            return [aUrl]
                        }
                        else {
                            return []
                        }
                    }
                    else {
                        var output: [NSURL] = []
                        let isRecursive = NSUserDefaults.standardUserDefaults().boolForKey(kDefaultsRecursive)
                        
                        var options:NSDirectoryEnumerationOptions = [NSDirectoryEnumerationOptions.SkipsPackageDescendants]
                        if !isRecursive {
                            options.insert(NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants)
                        }
                        
                        let enumerator = NSFileManager.defaultManager().enumeratorAtURL(aUrl, includingPropertiesForKeys: [NSURLIsDirectoryKey], options: options, errorHandler: { (url, error) -> Bool in
                            return true
                        })
                        
                        if let enumerator = enumerator {
                            for url in enumerator {
                                if let url = url as? NSURL {
                                    if fileIsRegularFile(url) {
                                        if checkIfFiletypeIsAllowed(url) {
                                            output.append(url)
                                        }
                                    }
                                }
                            }
                        }
                        
                        return output
                    }
                }
                else {
                    return []
                }
            }
            
            let dedupe = { (paths: [String]) -> [String] in
                var set: [String:Bool] = [:]
                let indicesToRemove = NSMutableIndexSet()
                
                for (i, path) in paths.enumerate() {
                    if set[path] != nil {
                        indicesToRemove.addIndex(i)
                    }
                    else {
                        set[path] = true
                    }
                }
                
                let sanitizedArray = NSMutableArray(array: paths)
                sanitizedArray.removeObjectsAtIndexes(indicesToRemove)
                
                if let output = sanitizedArray as NSArray as? [String] {
                    return output
                }
                else {
                    return []
                }
            }
            
            // filter out the current files that can be processed
            let outputStructs = self.files.filter({ (tuple:(path:String,status:FileStatus,error:ProcessorError?)) -> Bool in
                return tuple.status == .Ready
            })
            
            // get their path
            var output = outputStructs.map({
                $0.path
            })
            
            // find new files
            for (_, element) in files.enumerate() {
                let urls = recursiveSearch(element)
                
                var paths: [String] = []
                
                for url in urls {
                    if let path = url.path {
                        paths.append(path)
                    }
                }
                
                output += paths
            }
            
            // dedupe
            output = dedupe(output)
            
            // re-convert to structs
            let structs: [(path:String,status:FileStatus,error:ProcessorError?)] = output.map({
                ($0, FileStatus.Ready, nil as ProcessorError?)
            })
            
            self.files = structs
            self.tableView?.reloadData()
            
            if self.files.count != 0 {
                self.openPanel(true, animated: true)
                
                if let tableView = self.tableView {
                    tableView.scrollRowToVisible(self.numberOfRowsInTableView(tableView) - 1)
                }
                
                self.setDropletMode(self.dropletNonHoverMode())
            }
            
            if dropper == self.tableViewDropper {
                self.dropperBounce()
            }
            
            return true
        }
        else {
            return false
        }
    }
}
