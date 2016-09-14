//
//  Processor.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-8-27.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

import Foundation

func processImage(image: NSImage, resolution: CGSize, blur: Bool, color: NSColor?, blurConstant: CGFloat, shadowConstant: CGFloat, minimumEdgeGapToHeightRatio: CGFloat, targetBackgroundScale: CGFloat, maximumStretchScale: CGFloat, maximumBlurRadius: CGFloat, shadowAlpha: CGFloat) -> NSBitmapImageRep? {
    // nil only if blur
    var actualColor: NSColor? = nil
    
    if !blur {
        if color == nil {
            // resize image to one where the largest side is 800px — makes for much faster analysis
            let maxSize: CGFloat = 800
            let ratio: CGFloat = {
                if image.size.width > image.size.height {
                    return maxSize / image.size.width
                }
                else {
                    return maxSize / image.size.height
                }
            }()
            
            let colorArt = SLColorArt(image: image, scaledSize: CGSizeMake(image.size.width * ratio, image.size.height * ratio))
            
            if let color = colorArt.backgroundColor {
                actualColor = color
            }
            else {
                actualColor = NSColor.whiteColor()
            }
        }
        else {
            actualColor = color
        }
    }
    
    let width = resolution.width
    let height = resolution.height
    
    let minimumHorizontalGap = CGFloat(minimumEdgeGapToHeightRatio * width)
    let minimumVerticalGap = CGFloat(minimumEdgeGapToHeightRatio * height)
    
    ///////////////////////////
    // CREATE THE BASE FRAME //
    ///////////////////////////
    
    let baseViewFrame = CGRectMake(CGFloat(0.0), CGFloat(0.0), CGFloat(width), CGFloat(height))
    
    ////////////////////////////
    // CREATE THE IMAGE FRAME //
    ////////////////////////////
    
    var imageViewFrame = CGRectMake(0, 0, image.size.width * maximumStretchScale, image.size.height * maximumStretchScale)
    
    var imageViewXScale = CGFloat(1)
    var imageViewYScale = CGFloat(1)
    
    if (imageViewFrame.size.width > baseViewFrame.size.width - minimumHorizontalGap) {
        imageViewXScale = (baseViewFrame.size.width - minimumHorizontalGap) / imageViewFrame.size.width
    }
    if (imageViewFrame.size.height > baseViewFrame.size.height - minimumVerticalGap) {
        imageViewYScale = (baseViewFrame.size.height - minimumVerticalGap) / imageViewFrame.size.height
    }
    
    let imageViewScale = min(imageViewXScale, imageViewYScale)
    
    var frame = NSMakeRect(0, 0, imageViewFrame.size.width * imageViewScale, imageViewFrame.size.height * imageViewScale)
    frame.origin = NSMakePoint((baseViewFrame.size.width - frame.size.width) / 2.0, (baseViewFrame.size.height - frame.size.height) / 2.0)
    imageViewFrame = frame;
    
    /////////////////////////////////
    // CREATE THE BACKGROUND FRAME //
    /////////////////////////////////
    
    let blurImageViewXScale = max(targetBackgroundScale, baseViewFrame.size.width / imageViewFrame.size.width)
    let blurImageViewYScale = max(targetBackgroundScale, baseViewFrame.size.height / imageViewFrame.size.height)
    
    let blurImageViewScale = max(blurImageViewXScale, blurImageViewYScale)
    
    var newFrame = CGRectMake(0, 0, imageViewFrame.size.width * blurImageViewScale, imageViewFrame.size.height * blurImageViewScale)
    newFrame.origin = NSMakePoint((baseViewFrame.size.width - newFrame.size.width) / 2.0, (baseViewFrame.size.height - newFrame.size.height) / 2.0)
    let blurImageViewFrame = newFrame
    
    ///////////////////////
    // PAINT THE CONTENT //
    ///////////////////////
    
    if let outputImageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(baseViewFrame.size.width), pixelsHigh: Int(baseViewFrame.size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSDeviceRGBColorSpace, bytesPerRow: 0, bitsPerPixel: 0) {
        let context = NSGraphicsContext(bitmapImageRep: outputImageRep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrentContext(context)
        
        // fill with white (just in case)
        NSColor.whiteColor().setFill()
        NSRectFill(NSMakeRect(0, 0, outputImageRep.size.width, outputImageRep.size.height))
        
        // paint the image/color in the enlarged frame for the blurred background
        if let color = actualColor {
            color.setFill()
            NSRectFill(NSMakeRect(0, 0, blurImageViewFrame.size.width, blurImageViewFrame.size.height))
        }
        else {
            let displayFrame = NSMakeRect(0, 0, outputImageRep.size.width, outputImageRep.size.height)
            let backgroundImageFrame = NSMakeRect(0, 0, image.size.width, image.size.height)
            
            let translate = CGAffineTransformMakeTranslation(displayFrame.origin.x - blurImageViewFrame.origin.x, displayFrame.origin.y - blurImageViewFrame.origin.y)
            let scale = CGAffineTransformMakeScale(displayFrame.size.width / blurImageViewFrame.size.width, displayFrame.size.height / blurImageViewFrame.size.height)
            let scaleOldNew = CGAffineTransformMakeScale(backgroundImageFrame.size.width / blurImageViewFrame.size.width, backgroundImageFrame.size.height / blurImageViewFrame.size.height)
            
            // Instead of painting the image into the blurImageViewFrame (which can be enormous in the case of thin + long images),
            // we can find the inverse transform and sample the correct viewport portion of the unresized image.
            var transform = CGAffineTransformIdentity
            transform = CGAffineTransformConcat(transform, CGAffineTransformInvert(scaleOldNew))
            transform = CGAffineTransformConcat(transform, scale)
            transform = CGAffineTransformConcat(transform, translate)
            transform = CGAffineTransformConcat(transform, scaleOldNew)

            let innerFrame: NSRect = CGRectApplyAffineTransform(backgroundImageFrame, transform)
            
            image.drawInRect(NSMakeRect(0, 0, outputImageRep.size.width, outputImageRep.size.height), fromRect: innerFrame, operation: NSCompositeCopy, fraction: 1, respectFlipped: false, hints: nil)
        }
        
        // actually blur the background if needed
        if blur {
            let tintColor = NSColor(white: 1, alpha: 0.3)
            
            var blurRadius = blurConstant * resolution.height
            if blurRadius > maximumBlurRadius {
                NSLog("Blur radius for resolution \(resolution) clamped from \(blurRadius) to \(maximumBlurRadius)")
                blurRadius = maximumBlurRadius
            }
            let blurredImageRep = NSImageEffects.imageRepByApplyingBlurToImageRep(outputImageRep, withRadius: blurRadius, tintColor: tintColor, saturationDeltaFactor: 1.8, maskImage: nil)
            
            let blurredImageRect = NSMakeRect(0, 0, outputImageRep.size.width, outputImageRep.size.height);
            blurredImageRep.drawInRect(blurredImageRect)
        }
        
        // get the image rect
        var imageRect = imageViewFrame
        imageRect.origin = NSMakePoint((outputImageRep.size.width - imageRect.size.width) / 2.0, (outputImageRep.size.height - imageRect.size.height) / 2.0)
        
        // paint the shadow
        if let ctx = NSGraphicsContext.currentContext()?.CGContext {
            CGContextSaveGState(ctx)
            let shadowPath = NSBezierPath(rect: imageRect)
            let shadowBlur = resolution.height * shadowConstant
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0), shadowBlur, NSColor.blackColor().colorWithAlphaComponent(shadowAlpha).CGColor)
            shadowPath.fill()
            CGContextRestoreGState(ctx)
        }
        
        // paint the image
        image.drawInRect(imageRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        return outputImageRep
    }
    else {
        return nil
    }
}
