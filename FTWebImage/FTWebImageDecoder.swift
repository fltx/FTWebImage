//
//  FTWebImageDecode.swift
//  Test
//
//  Created by Neo on 16/5/12.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit
import CoreGraphics

extension UIImage{
    
    class func decodedImage(image : UIImage) -> UIImage{
        if image.images != nil{
            return image
        }
        
        let imageRef = image.CGImage
        let alpha = CGImageGetAlphaInfo(imageRef)
        let hasAlpha = (alpha == .None || alpha == .NoneSkipFirst || alpha == .NoneSkipLast)
        if hasAlpha{
            return image
        }
        
        var imageWithAlpha  :UIImage!
        autoreleasepool { () -> () in
            var colorSpaceRef = CGImageGetColorSpace(imageRef)
            let imageColorSpaceModel = CGColorSpaceGetModel(colorSpaceRef)
            let unsupportedColorSpace = (imageColorSpaceModel == .Unknown || imageColorSpaceModel == .Monochrome || imageColorSpaceModel == .CMYK || imageColorSpaceModel == .Indexed)
            if unsupportedColorSpace
            {
                colorSpaceRef = CGColorSpaceCreateDeviceRGB()
            }
            
            let width = CGImageGetWidth(imageRef)
            let height = CGImageGetHeight(imageRef)
            let bytesPerpixel = 4
            let bytesPerRow = bytesPerpixel * width
            let bitsPerComponent = 8
            let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, colorSpaceRef,1)
            CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), imageRef)
            let imageRefWithAlpha = CGBitmapContextCreateImage(context)
            imageWithAlpha = UIImage(CGImage: imageRefWithAlpha!, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return imageWithAlpha
    }
}
