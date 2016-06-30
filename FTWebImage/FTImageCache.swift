//
//  FTImageCache.swift
//  FTWebImage
//
//  Created by Neo on 16/4/8.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit
import Foundation
import CoreGraphics

enum FTImageCacheType{
    case None,Disk,Memory
}

enum FTWebImageCacheType{
    case None,Disk,Memory
}

class AutoPurgeCache: NSCache {
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(removeAllObjects), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
}


private let kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7 //1 week
private let kPNGSignatureBytes = NSData(bytes: UnsafePointer<UInt8>([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), length: 8)
private let kPNGSignatureData = NSData(bytes: UnsafePointer<UInt8>([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), length: 8)

func ImageDataHasPNGPreffix(data : NSData) -> Bool{
    let pngSignatureLength = kPNGSignatureData.length
    if data.length >= pngSignatureLength{
        if data.subdataWithRange(NSMakeRange(0, pngSignatureLength)).isEqualToData(kPNGSignatureData) {
            return true
        }
    }
    return false
}

func FTCacheCostForImage(image : UIImage) -> Int {
    return Int(image.size.height * image.size.width * image.scale * image.scale)
}

class FTImageCache: NSObject {
    static let sharedImageCache = FTImageCache()
    var shouldDisableiCloud = true
    var shouldDecompressImages = true
    var shouldCachedImagesInMemory = true
    var maxMemoryCost : Int = 0
    var maxMemoryCountLimit : Int = 0
    var maxCacheAge : Int = kDefaultCacheMaxCacheAge
    var maxCacheSize : Int = 0
    private var memoryCache = AutoPurgeCache()
    private var diskCachePath : String!
    private var customPaths : NSMutableArray!
    private var ioQueue : dispatch_queue_t = dispatch_queue_create("com.ftx.FTWebImageCache", DISPATCH_QUEUE_SERIAL)
    private var fileManager : NSFileManager!
    
    override init() {
        super.init()
        let path = makeDiskCachePath("default")
        let fullNameSpace = "com.fltx.FTWebImageCache\(path)"
        memoryCache.name = fullNameSpace
        diskCachePath = path
        dispatch_sync(ioQueue) {
            self.fileManager = NSFileManager()
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(clearMemory), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(clearDisk), name: UIApplicationWillTerminateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(backgroundCleanDisk), name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func clearMemory() {
        memoryCache.removeAllObjects()
    }
    
    func clearDisk() {
        clearDiskOnCompletion(nil)
    }
    
    func clearDiskOnCompletion(completionClosure : FTWebImageNoParamsClosure?){
        dispatch_async(ioQueue) {
            do{
                try self.fileManager.removeItemAtPath(self.diskCachePath)
                try  self.fileManager.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
            }catch{
                
            }
            if let completion = completionClosure{
                completion()
            }
        }
    }
    
    
    func cleanDisk() {
        cleanDiskWithCompletion(nil)
    }
    
    func cleanDiskWithCompletion(completionClosure : FTWebImageNoParamsClosure?) {
        dispatch_async(ioQueue) {[weak self]() -> Void in
            if let strongSelf = self{
                let diskCacheURL = NSURL(fileURLWithPath: strongSelf.diskCachePath)
                let resourceKeys = [NSURLIsDirectoryKey,NSURLContentModificationDateKey,NSURLTotalFileAllocatedSizeKey]
                let fileEnumerator = strongSelf.fileManager.enumeratorAtURL(diskCacheURL, includingPropertiesForKeys: resourceKeys, options: .SkipsHiddenFiles, errorHandler: nil)
                let expirationDate = NSDate(timeIntervalSinceNow: -Double(strongSelf.maxCacheAge))
                let cacheFiles = NSMutableDictionary()
                var currentCacheSize = 0
                let urlsToDelete = NSMutableArray()
                for fileURL in fileEnumerator!{
                    do{
                        let resourceValues = try fileURL.resourceValuesForKeys(resourceKeys)
                        if ((resourceValues[NSURLIsDirectoryKey]?.boolValue) != nil){
                            continue
                        }
                        let modificationDate = resourceValues[NSURLContentModificationDateKey]
                        if ((modificationDate?.laterDate(expirationDate).isEqualToDate(expirationDate)) != nil){
                            urlsToDelete.addObject(fileURL)
                            continue
                        }
                        let totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey]
                        currentCacheSize += (totalAllocatedSize?.integerValue)!
                        cacheFiles.setObject(resourceValues, forKey: fileURL as! NSURL)
                        
                        for fileURL in urlsToDelete{
                            do{
                                try
                                    strongSelf.fileManager.removeItemAtURL(fileURL as! NSURL)
                            }catch{
                            }
                        }
                        
                        
                        if strongSelf.maxCacheSize > 0 && currentCacheSize > strongSelf.maxCacheSize{
                            let desiredCacheSize = strongSelf.maxCacheSize / 2
                            let sortedFiles = cacheFiles.keysSortedByValueWithOptions(NSSortOptions.Concurrent, usingComparator: { (obj1, obj2) -> NSComparisonResult in
                                return .OrderedAscending
                                //return obj1[NSURLContentModificationDateKey].compare(obj2[NSURLContentModificationDateKey])
                            })
                            
                            for fileURL in sortedFiles{
                                do {
                                    try
                                    strongSelf.fileManager.removeItemAtURL(fileURL as! NSURL)
                                    let url = fileURL as! NSURL
                                    let resourceValues = cacheFiles[url]
                                    let totalAllocatedSize = resourceValues![NSURLTotalFileAllocatedSizeKey]
                                    currentCacheSize -= totalAllocatedSize!!.integerValue
                                    if currentCacheSize < desiredCacheSize{
                                        break
                                    }
                                }catch{
                                    
                                }
                            }
                            dispatch_async(dispatch_get_main_queue(), {
                                completionClosure?()
                            })
                        }
                    }catch{
                        
                    }
                }
            }
        }
    }
    
    func backgroundCleanDisk() {
        let application = UIApplication.sharedApplication()
        var bgTask : UIBackgroundTaskIdentifier? = nil
        bgTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler {
            application.endBackgroundTask(bgTask!)
            bgTask = UIBackgroundTaskInvalid
        }
        cleanDiskWithCompletion {
            application.endBackgroundTask(bgTask!)
            bgTask = UIBackgroundTaskInvalid
        }
    }
    
    func getSize() ->  Int{
        var size : UInt64 = 0
        dispatch_sync(ioQueue) {
            let fileEnumerator = self.fileManager.enumeratorAtPath(self.diskCachePath)
            for fileName in fileEnumerator!{
                let filePath = (self.diskCachePath as NSString).stringByAppendingPathComponent(fileName as! String)
                do{
                    let attrs = try NSFileManager.defaultManager().attributesOfItemAtPath(filePath) as NSDictionary
                    size += attrs.fileSize()
                }catch{
                    
                }
            }
        }
        return Int(size)
    }
    
    func getDiskCount() -> Int {
        var count = 0
        dispatch_sync(ioQueue) {
            let fileEnumerator = self.fileManager.enumeratorAtPath(self.diskCachePath)
            count = fileEnumerator!.allObjects.count
        }
        return count
    }
    
    func calculateSize(completionClosure : FTWebImageCalculateSizeClosure?)  {
        let diskCacheURL = NSURL(fileURLWithPath:diskCachePath, isDirectory: true)
        dispatch_async(ioQueue) {
            var fileCount = 0
            var totalSize : Int = 0
            let fileEnumerator = self.fileManager.enumeratorAtURL(diskCacheURL, includingPropertiesForKeys: [NSFileSize], options: .SkipsHiddenFiles, errorHandler: nil)
            for fileURL in fileEnumerator!{
                var fileSize : AnyObject? = 0
                //                do {
                //                    try
                //                        fileURL.getResourceValue(&fileSize, forKey: NSURLFileSizeKey)
                //                    var anyError: NSError?
                //                    var rsrc: AnyObject?
                //                    var success = fileURL.getResourceValue(&rsrc, forKey:NSURLIsUbiquitousItemKey, error:&anyError)
                //                }catch{
                //
                //                }
                totalSize += fileSize!.integerValue
                fileCount += 1
            }
            
            if let completion = completionClosure{
                dispatch_async(dispatch_get_main_queue(), {
                    completion(fileCount: fileCount, totalSize: totalSize)
                })
            }
        }
    }
    
    func addReadOnlyCachePath(path : String) {
        if customPaths == nil {
            customPaths = NSMutableArray()
        }
        if !customPaths!.containsObject(path) {
            customPaths!.addObject(path)
        }
    }
    
    func cachePathForKey(key : String,path : String) -> String {
        let fileName = cachedFileNameForKey(key)
        return (path as NSString).stringByAppendingPathComponent(fileName)
    }
    
    func defaultCachePathForKey(key : String) -> String {
        return cachePathForKey(key, path: diskCachePath)
    }
    
    func cachedFileNameForKey(key : String) -> String {
        return NSUUID().UUIDString + "\(key)"
    }
    
    
    
    // Init the disk cache
    func makeDiskCachePath(fullNamespace : String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0] as NSString
        return paths.stringByAppendingPathComponent(fullNamespace)
    }
    
    func storeImage(image : UIImage,key : String,toDisk : Bool) {
        storeImage(image, recalculateFromImage: true, imageData: nil, key: key, toDisk: toDisk)
    }
    
    func storeImage(image : UIImage,key : String){
        storeImage(image, recalculateFromImage: true, imageData: nil, key: key, toDisk: true)
    }
    
    func storeImage(image : UIImage,recalculateFromImage : Bool,imageData : NSData?,key : String,toDisk : Bool) {
        if shouldCachedImagesInMemory {
            let cost = FTCacheCostForImage(image)
            memoryCache.setObject(image, forKey: key, cost: Int(cost))
        }
        
        if toDisk {
            dispatch_async(ioQueue, {
                var data  = imageData
                if recalculateFromImage || data == nil{
                    // We need to determine if the image is a PNG or a JPEG
                    // PNGs are easier to detect because they have a unique signature (http://www.w3.org/TR/PNG-Structure.html)
                    // The first eight bytes of a PNG file always contain the following (decimal) values:
                    // 137 80 78 71 13 10 26 10
                    
                    // If the imageData is nil (i.e. if trying to save a UIImage directly or the image was transformed on download)
                    // and the image has an alpha channel, we will consider it PNG to avoid losing the transparency
                    let alphaInfo = CGImageGetAlphaInfo(image.CGImage)
                    let hasAlpha = !(alphaInfo == .None || alphaInfo == .NoneSkipFirst || alphaInfo == .NoneSkipLast)
                    var imageIsPng = hasAlpha
                    // But if we have an image data, we will look at the preffix
                    if imageData?.length > kPNGSignatureData.length{
                        imageIsPng = ImageDataHasPNGPreffix(imageData!)
                    }
                    if imageIsPng{
                        data = UIImagePNGRepresentation(image)
                    }else{
                        data = UIImageJPEGRepresentation(image, 1.0)
                    }
                }
                if data != nil{
                    if !self.fileManager.fileExistsAtPath(self.diskCachePath){
                        do{
                            try self.fileManager.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
                        }catch{
                            NSLog("Create filePath  \(self.diskCachePath) failed")
                        }
                    }
                    let cachePathForKey = self.defaultCachePathForKey(key)
                    let fileURL = NSURL(fileURLWithPath: cachePathForKey)
                    self.fileManager.createFileAtPath(cachePathForKey, contents: data!, attributes: nil)
                    if self.shouldDisableiCloud{
                        do{
                            try fileURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
                        }catch{
                            NSLog("Create file failed")
                        }
                    }
                }
            })
        }
    }
    
    func diskImageExistsWithKey(key : String) -> Bool{
        var exists = false
        // this is an exception to access the filemanager on another queue than ioQueue, but we are using the shared instance
        // from apple docs on NSFileManager: The methods of the shared NSFileManager object can be called from multiple threads safely.
        exists = NSFileManager.defaultManager().fileExistsAtPath(defaultCachePathForKey(key))
        // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
        // checking the key with and without the extension
        if !exists{
            exists = NSFileManager.defaultManager().fileExistsAtPath((defaultCachePathForKey(key) as NSString).stringByDeletingPathExtension)
        }
        return exists
    }
    
    func diskImgaeExistsWithKey(key : String,completion completionBlock : FTWebImageCheckCacheCompletionClosure?){
        dispatch_async(ioQueue) {
            var exists = self.fileManager.fileExistsAtPath(self.defaultCachePathForKey(key))
            // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
            // checking the key with and without the extension
            if !exists{
                exists = NSFileManager.defaultManager().fileExistsAtPath((self.defaultCachePathForKey(key) as NSString).stringByDeletingPathExtension)
            }
            if let completionBlock = completionBlock{
                dispatch_async(dispatch_get_main_queue(), {
                    completionBlock(isInCache: exists)
                })
            }
        }
    }
    
    func imageFromMemoryCacheForKey(key : String) -> UIImage?{
        return memoryCache.objectForKey(key) as? UIImage
    }
    
    func diskImageForKey(key : String) -> UIImage? {
        if let data = diskImageDataBySearchAllPathsForKey(key)
        {
            var image = UIImage.ft_imageWithData(data)
            image = scaledImageForKey(key, image: image)
            if  shouldDecompressImages {
                // image = ////
            }
            return image
        }
        return nil
    }
    
    func scaledImageForKey(key : String,image : UIImage?) -> UIImage?{
        return FTScaledImageForKey(key, image: image)
    }
    
    func diskImageDataBySearchAllPathsForKey(key : String) -> NSData? {
        let defaultPath = defaultCachePathForKey(key)
        var data = NSData(contentsOfFile: defaultPath)
        if data != nil {
            return data
        }
        data = NSData(contentsOfFile: (defaultPath as NSString).stringByDeletingPathExtension)
        if data != nil {
            return data
        }
        let paths = customPaths.copy() as! NSArray
        for path in paths{
            let filePath = cachePathForKey(key, path: path as! String)
            var imageData = NSData(contentsOfFile: filePath)
            if imageData != nil{
                return imageData
            }
            
            imageData = NSData(contentsOfFile: (filePath as? NSString)!.stringByDeletingPathExtension)
            if imageData != nil{
                return imageData
            }
        }
        return nil
    }
    
    func imageFromDiskCacheForKey(key : String) -> UIImage?{
        //Check Memory cache first
        var image = imageFromMemoryCacheForKey(key)
        if image != nil {
            return image
        }
        //Second check disk cache
        image = diskImageForKey(key)
        if image != nil && shouldCachedImagesInMemory {
            let cost = FTCacheCostForImage(image!)
            memoryCache.setObject(image!, forKey: key, cost: cost)
        }
        return image
    }
    
    func queryDiskCacheForKey(key : String?,doneClosure : FTWebImageQueryCompletedClosure) -> NSOperation? {
        if key == nil {
            doneClosure(image: nil, cacheType: .None)
            return nil
        }
        let image = imageFromMemoryCacheForKey(key!)
        if image != nil {
            doneClosure(image: image, cacheType: .Memory)
            return nil
        }
        let operation = NSOperation()
        dispatch_async(ioQueue) {
            if operation.cancelled{
                return
            }
            
            let diskImage = self.diskImageForKey(key!)
            if diskImage != nil && self.shouldCachedImagesInMemory{
                let cost = FTCacheCostForImage(diskImage!)
                self.memoryCache.setObject(diskImage!, forKey: cost)
            }
            dispatch_async(dispatch_get_main_queue(), {
                doneClosure(image: diskImage!, cacheType: .Disk)
            })
        }
        
        return operation
    }
    
    func removeImageForKey(key : String) {
        removeImageForKey(key, completionClosure: nil)
    }
    
    func removeImageForKey(key : String,completionClosure : FTWebImageNoParamsClosure?){
        removeImageForyKey(key, fromDisk: true, completionClosure: completionClosure)
    }
    
    func removeImageForKey(key : String,fromDisk : Bool) {
        removeImageForyKey(key, fromDisk: fromDisk, completionClosure: nil)
    }
    
    func removeImageForyKey(key : String,fromDisk : Bool,completionClosure : FTWebImageNoParamsClosure?){
        if shouldCachedImagesInMemory {
            memoryCache.removeObjectForKey(key)
        }
        
        if fromDisk {
            dispatch_async(ioQueue, {
                do{
                    try self.fileManager.removeItemAtPath(self.defaultCachePathForKey(key))
                }catch{
                    
                }
                
                if let completion = completionClosure{
                    dispatch_async(dispatch_get_main_queue(), {
                        completion()
                    })
                }
            })
        } else if let completion = completionClosure{
            completion()
        }
    }
}
