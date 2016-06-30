//
//  FTImage.swift
//  Test
//
//  Created by Neo on 16/4/14.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit
import ImageIO
import Foundation
import CoreGraphics

// MARK: - MultiFormat
extension UIImage{
    
    class func ft_imageWithData(data : NSData?) -> UIImage?{
        guard data == nil else{
            let imageContentType = NSData.ft_contentTypeForImageData(data!)
            var image : UIImage?
            if imageContentType == "image/gif" {
                image = UIImage.ft_animatedGIFWithData(data!)
            }else if imageContentType == "image/webp"{
                NSLog("webp image")
            }else{
                image = UIImage(data: data!)
                let orientation = ft_imageOrientationFromImageData(data!)
                if orientation != UIImageOrientation.Up{
                    image = UIImage(CGImage: image!.CGImage!, scale: image!.scale, orientation: orientation)
                }
            }
            return image
        }
        return nil
    }
    
    class func ft_imageOrientationFromImageData(imageData : NSData)-> UIImageOrientation{
        var result = UIImageOrientation.Up
        if let imageSource = CGImageSourceCreateWithData(imageData, nil){
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil){
                let propertyKey = unsafeBitCast(kCGImagePropertyOrientation, UnsafePointer<Void>.self)
                let val = CFDictionaryGetValue(properties, propertyKey)
                var exifOrientation : Int = 0
                if val != nil{
                    CFNumberGetValue(val as! CFNumber,CFNumberType.IntType, &exifOrientation)
                    result = orientationFromPropertyValue(exifOrientation)
                }
            }else{
                //No properties
            }
        }
        return result
    }
}

func orientationFromPropertyValue(value : Int) -> UIImageOrientation {
    switch value {
    case 1:
        return UIImageOrientation.Up
    case 2:
        return UIImageOrientation.UpMirrored
    case 3:
        return UIImageOrientation.Down
    case 4:
        return UIImageOrientation.DownMirrored
    case 5:
        return UIImageOrientation.LeftMirrored
    case 6:
        return UIImageOrientation.Right
    case 7:
        return UIImageOrientation.RightMirrored
    case 1:
        return UIImageOrientation.Left
    default:
        return UIImageOrientation.Up
    }
}




// MARK: - GIF
extension UIImage{
    
    class func ft_animatedGIFWithData(data : NSData?) -> UIImage?{
        guard data == nil else{
            let source = CGImageSourceCreateWithData(data!, nil)
            let count = CGImageSourceGetCount(source!)//GIF use
            var animatedImage : UIImage?
            if count <= 1{
                animatedImage = UIImage(data: data!)
            }else{
                var images = [UIImage]()
                var duration : NSTimeInterval = 0
                for i : size_t in 0 ..< count {
                    let image : CGImageRef? = CGImageSourceCreateImageAtIndex(source!, i, nil)
                    if image == nil{
                        continue
                    }
                    duration += Double(ft_frameDurationAtIndex(i,source: source!))
                    images.append(UIImage(CGImage: image!, scale: UIScreen.mainScreen().scale, orientation: UIImageOrientation.Up))
                }
                if duration < 0.01{
                    duration = (1.0 / 10.0) * Double(count)
                }
                animatedImage = UIImage.animatedImageWithImages(images, duration: duration)
            }
            return animatedImage
        }
        return nil
    }
    
    
    //duration time between gif image
    class func ft_frameDurationAtIndex(index : Int,source : CGImageSourceRef) -> CGFloat{
        var frameDuration : CGFloat = 0.1
        let cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let frameProperties = cfFrameProperties as! NSDictionary
        let gifProperties : NSDictionary = frameProperties[kCGImagePropertyGIFDictionary as String] as! NSDictionary
        if let delayTimeUnclampedProp = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String]
        {
            frameDuration = CGFloat((delayTimeUnclampedProp as! NSNumber))
        }else{
            if let delayTimeProp = gifProperties[kCGImagePropertyGIFDelayTime as String]{
                frameDuration = CGFloat(delayTimeProp as! NSNumber)
            }
        }
        if frameDuration < 0.011{
            frameDuration = 0.100
        }
        return frameDuration
    }
    
    class func ft_animatedGIFNamed(name : String) -> UIImage?{
        let scale = UIScreen.mainScreen().scale
        if scale > 1.0
        {
            let retainPath = NSBundle.mainBundle().pathForResource(name.stringByAppendingString("@2x"), ofType: "gif")
            if let data = NSData.init(contentsOfFile:retainPath!){
                return UIImage.ft_animatedGIFWithData(data)
            }
            return UIImage(named:name)
        }else{
            let path = NSBundle.mainBundle().pathForResource(name, ofType: "gif")
            if let data = NSData.init(contentsOfFile:path!)
            {
                return UIImage.ft_animatedGIFWithData(data)
            }
            return UIImage(named: name)
        }
    }
    
    
    func ft_animatedImgaeByScalingAndCroppingToSize(size : CGSize) -> UIImage?{
        if CGSizeEqualToSize(self.size, size) || CGSizeEqualToSize(size,CGSizeZero){
            return self
        }
        var scaledSize = size
        var thumbnailPoint = CGPointZero
        let widthFactor = size.width / self.size.width
        let heightFactor = size.height / self.size.height
        let scaleFactor = (widthFactor > heightFactor) ? widthFactor : heightFactor
        scaledSize.width = self.size.width * scaleFactor
        scaledSize.height = self.size.height * scaleFactor
        if widthFactor > heightFactor{
            thumbnailPoint.y = (size.height - scaledSize.height) * 0.5
        }else if(widthFactor < heightFactor){
            thumbnailPoint.x = (size.width - scaledSize.width) * 0.5
        }
        var scaledImages = [UIImage]()
        for image in self.images!{
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            image.drawInRect(CGRectMake(thumbnailPoint.x, thumbnailPoint.y, scaledSize.width, scaledSize.height))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            scaledImages.append(newImage)
            UIGraphicsEndImageContext()
        }
        return UIImage.animatedImageWithImages(scaledImages, duration: self.duration)
    }
}

