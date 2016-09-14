//
//  AppDelegate.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-8-25.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

// POSSIBLE FUTURE FEATURES:
//
//  * editable table view (delete rows)
//  * correct producer/consumer threads
//  * decreased memory usage
//  * preferences with:
//      * max scale factor
//      * shadow properties
//      * blur properties
//      * should touch edges?
//  * help
//  * services support
//  * command line support
//  * continuous drawRect with "auto" button
//  * alias, symlink support
//  * cancel button that works better
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    func applicationDidFinishLaunching(aNotification: NSNotification) {
    }
    
    func application(sender: NSApplication, openFile filename: String) -> Bool {
        self.application(sender, openFiles: [filename])
        return true
    }
    
    // handles dropping stuff onto the icon
    func application(sender: NSApplication, openFiles filenames: [String]) {
        if let controller = NSApplication.sharedApplication().mainWindow?.contentViewController as? ViewController {
            // TODO: kind of a quick hack; should really have toggle right in AppController
            let droppersDisabled: Bool = {
                if let droplet = controller.droplet {
                    if !droplet.enabled {
                        return true
                    }
                }
                if let droplet = controller.tableViewDropper {
                    if !droplet.enabled {
                        return true
                    }
                }
                
                return false
            }()
            
            if !droppersDisabled {
                var files: [NSURL] = []
                
                for filename in filenames {
                    if let url: NSURL = NSURL(fileURLWithPath: filename) {
                        files.append(url)
                    }
                }
                
                controller.dropperDidGetFiles(controller.view, files: files)
                controller.dropperBounce()
            }
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }

}
