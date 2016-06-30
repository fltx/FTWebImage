//
//  FTData.swift
//  Test
//
//  Created by Neo on 16/4/14.
//  Copyright © 2016年 XM. All rights reserved.
//

import Foundation


// MARK: - ImageType
extension NSData{
    class func contentTypeForImageData(data : NSData) -> String?{
        return ft_contentTypeForImageData(data)
    }
    
    class func ft_contentTypeForImageData(data : NSData) -> String? {
        var c : __uint8_t = 0
        data.getBytes(&c, length: 1)
        switch c {
        case 0xFF:
            return "image/jpeg"
        case 0x89:
            return "image/png"
        case 0x47:
            return "image/gif"
        case 0x49:
            return "image/tiff"
        case 0x4D:
            return "image/tiff"
        case 0x52:
            // R as RIFF for WEBP
            if data.length < 12 {
                return nil
            }
            let string = NSString(data: data.subdataWithRange(NSMakeRange(0, 12)), encoding: NSASCIIStringEncoding)
            if string!.hasPrefix("RIFF") && string!.hasPrefix("WEBP") {
                return "image/webp"
            }
            return nil
        default:
            return nil
        }
    }
    
}