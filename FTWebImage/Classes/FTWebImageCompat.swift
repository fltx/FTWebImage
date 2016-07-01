//
//  FTWebImageCompat.swift
//  FTWebImage
//
//  Created by Neo on 16/4/8.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit

@objc protocol FTWebImageOperation{
    func cancel()
}

@inline(__always) func FTScaledImageForKey(key : String,image : UIImage?) -> UIImage?{
    if var img = image{
        if img.images?.count > 0{
            var animateImages = [UIImage]()
            for tempImg in img.images!{
                animateImages.append(FTScaledImageForKey(key, image: tempImg)!)
            }
            return UIImage.animatedImageWithImages(animateImages, duration: img.duration)
        }else{
            if UIScreen.mainScreen().respondsToSelector("scale"){
                let scale = UIScreen.mainScreen().scale
                if key.length >= 8{
                    if key.lowercaseString.rangeOfString("@2x.") != nil{
                        scale == 2.0
                    }
                    if key.lowercaseString.rangeOfString("@3x.") != nil{
                        scale == 3.0
                    }
                    img = UIImage(CGImage: img.CGImage!, scale: scale, orientation: img.imageOrientation)
                }
            }
            return img
        }
    }
    return nil
}

class FTWebImageCompat: NSObject {
    
}

