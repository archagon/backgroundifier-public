//
//  Main.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-8-27.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

import Foundation
import AppKit

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

let defaults: [NSObject:AnyObject] = [
    kDefaultsRecursive:true,
    kDefaultsOverwrite:false,
    kDefaultsBlurred:true,
    kDefaultsAuto:true,
    kDefaultsColor:NSArchiver.archivedDataWithRootObject(NSColor.blueColor()),
    kDefaultsBlurConstant:(200.0 / 2100.0), // magic number based on what looks good at my laptop resolution
    kDefaultsShadowConstant:(78.0 / 2100.0), // magic number based on what looks good at my laptop resolution
    kDefaultsMinimumEdgeGapToHeightRatio:0.125,
    kDefaultsTargetBackgroundScale:1.5,
    kDefaultsMaximumStretchScale:10000, // functionally infinity
    kDefaultsShadowAlpha:0.5
]
NSUserDefaults.standardUserDefaults().registerDefaults(defaults)

if contains(Process.arguments, "-test") {
    print("just testing here!\n")
}
else {
    NSApplicationMain(Process.argc, Process.unsafeArgv)
}