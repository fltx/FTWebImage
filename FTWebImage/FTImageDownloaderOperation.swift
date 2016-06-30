//
//  FTImageDownloaderOperation.swift
//  Test
//
//  Created by Neo on 16/4/8.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit
import Foundation
import ImageIO
import CoreGraphics

class FTImageDownloaderOperation: NSOperation,FTWebImageOperation,NSURLConnectionDataDelegate{
    private(set) var request : NSURLRequest?
    var shouldDecompressImages = true
    var shouldUseCredentialStorage = true
    var credential : NSURLCredential?
    private(set) var options : FTWebImageDownloaderOptions?
    var expectedSize : Int = 0
    var response : NSURLResponse?
    
    private var progressClosure : FTWebImageDownloaderProgressClosure?
    private var completedColsure : FTWebImageDownloaderCompletedClosure?
    private var cancelClosure : FTWebImageNoParamsClosure?
    private var isExecuting : Bool = false
    private var isFinished : Bool = false
    override var executing : Bool{
        get{
            return isExecuting
        }
        set{
            if executing == newValue{
                return
            }
            willChangeValueForKey("isExecuting")
            isExecuting = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    
    override var finished: Bool
        {
        get{
            return isFinished
        }
        set{
            if finished == newValue{
                return
            }
            willChangeValueForKey("isFinished")
            isFinished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    
    private var imageData : NSMutableData?
    private var connection : NSURLConnection?
    private var thread : NSThread?
    
    private var _backgoundTaskId: AnyObject?
    @available(iOS 8.0, *)
    private var backgoundTaskId : UIBackgroundTaskIdentifier?{
        get {
            return _backgoundTaskId as? UIBackgroundTaskIdentifier
        }
        set {
            _backgoundTaskId = newValue
        }
    }
    
    private var width : size_t = 0
    private var height : size_t = 0
    private var orientation : UIImageOrientation?
    private var responseFromCached : Bool = true
    
    override init() {
        super.init()
    }
    
    convenience init(request : NSURLRequest,options : FTWebImageDownloaderOptions,progress progressClosure: FTWebImageDownloaderProgressClosure,completed completedColsure : FTWebImageDownloaderCompletedClosure,cancelled cancelClosure : FTWebImageNoParamsClosure) {
        self.init()
        self.request = request
        self.options = options
        self.progressClosure = progressClosure
        self.completedColsure = completedColsure
        self.cancelClosure = cancelClosure
    }
    
    override func start() {
        objc_sync_enter(self)
        if cancelled{
            finished = true
            reset()
            return
        }
        
        if #available(iOS 4.0, *)  {
            if options != nil && options == .ContinueInBackground{
                let app = UIApplication.sharedApplication()
                backgoundTaskId = app.beginBackgroundTaskWithExpirationHandler({[weak self] () -> Void in
                    if let strongSelf = self{
                        strongSelf.cancel()
                        app.endBackgroundTask(strongSelf.backgoundTaskId!)
                        strongSelf.backgoundTaskId = UIBackgroundTaskInvalid
                    }
                    })
            }
        }
        executing = true
        connection = NSURLConnection(request: request!, delegate: self, startImmediately: false)
        thread = NSThread.currentThread()
        objc_sync_exit(self)
        connection?.start()
        
        if let _connection = connection
        {
            progressClosure?(receivedSize: 1,expectedSize:-1)
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.Start, object: self)
            })
            if floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_5_1{
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, false)
            }else{
                CFRunLoopRun()
            }
            if !isFinished{
                _connection.cancel()
                let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSURLErrorFailingURLErrorKey : (request?.URL)!])
                connection(_connection, didFailWithError: error)
            }
        }else{
            let error = NSError(domain: NSURLErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Connection can't be initialized"])
            completedColsure?(image: nil,data: nil,error: error,finished: true)
        }
        
        if #available(iOS 4.0,*){
            if backgoundTaskId != UIBackgroundTaskInvalid{
                UIApplication.sharedApplication().endBackgroundTask(backgoundTaskId!)
                backgoundTaskId = UIBackgroundTaskInvalid
            }
        }
    }
    
    override func cancel() {
        objc_sync_enter(self)
        if let _thread = thread{
            performSelector("cancelInternalAndStop", onThread:_thread, withObject: nil, waitUntilDone: false)
        }else{
            cancelInternal()
        }
        objc_sync_exit(self)
    }
    
    func cancelInternalAndStop()
    {
        if isFinished{
            return
        }
        cancelInternal()
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    
    func cancelInternal(){
        if isFinished{
            return
        }
        super.cancel()
        cancelClosure?()
        if let _connection = connection{
            _connection.cancel()
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.Stop, object: self)
            })
            if isExecuting{
                executing = false
            }
            if !isFinished{
                finished = true
            }
        }
        reset()
    }
    
    func done(){
        finished = true
        executing = false
        reset()
    }
    
    @available(iOS 7.0,*)
    func setOperation(){
        
    }
    
    func reset() {
        cancelClosure = nil
        completedColsure = nil
        progressClosure = nil
        connection = nil
        imageData = nil
        thread = nil
    }
    
    //MARK:- Action
    
    func scaleImageForKey(key : String,image : UIImage) -> UIImage{
        return scaleImageForKey(key, image: image)
    }
    
    //MARK:- NSURLConnectionDelegate
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        let code = (response as! NSHTTPURLResponse).statusCode
        if response.respondsToSelector("statusCode") || (code < 400 && code != 304 ) {
            let expected : Int = response.expectedContentLength > 0 ? Int(response.expectedContentLength) : 0
            expectedSize = expected
            progressClosure?(receivedSize: 0,expectedSize: expected)
            imageData = NSMutableData(capacity: expected)
            self.response = response
            dispatch_async(dispatch_get_main_queue(), {
                NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.ReceiveResponse, object: self)
            })
        }else{
            if code == 304 {
                cancelInternal()
            }else{
                connection.cancel()
            }
            dispatch_async(dispatch_get_main_queue(), {
                NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.Stop, object: self)
            })
            let error = NSError(domain: NSURLErrorDomain, code: code, userInfo: nil)
            completedColsure?(image: nil,data: nil,error: error,finished: true)
            CFRunLoopStop(CFRunLoopGetCurrent())
            done()
        }
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        imageData!.appendData(data)
        if options != nil && options == .ProgressiveDownload && expectedSize > 0 && completedColsure != nil{
            let totalSize = imageData?.length
            let imageSource = CGImageSourceCreateWithData(imageData!, nil)
            if width + height == 0{
                /*
                 let properties1 = CGImageSourceCopyPropertiesAtIndex(imageSource!, Int(0), nil)
                 if (properties1 != nil) {
                 let gifDictionaryProperty = unsafeBitCast(kCGImagePropertyPixelHeight, UnsafePointer<Void>.self)
                 let gifProperties = CFDictionaryGetValue(properties1, gifDictionaryProperty)
                 
                 if (gifProperties != nil) {
                 let gifPropertiesCFD = unsafeBitCast(gifProperties, CFDictionary.self)
                 
                 let unclampedDelayTimeProperty = unsafeBitCast(kCGImagePropertyGIFUnclampedDelayTime, UnsafePointer<Void>.self)
                 var number = unsafeBitCast(CFDictionaryGetValue(gifPropertiesCFD, unclampedDelayTimeProperty), NSNumber.self);
                 
                 if (number.doubleValue == 0) {
                 let delayTimeProperty = unsafeBitCast(kCGImagePropertyGIFDelayTime, UnsafePointer<Void>.self)
                 number = unsafeBitCast(CFDictionaryGetValue(gifPropertiesCFD, delayTimeProperty), NSNumber.self);
                 }
                 }
                 }
                 */
                
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource!, 0, nil){
                    var orientationValue = -1
                    var propertyKey = unsafeBitCast(kCGImagePropertyPixelHeight, UnsafePointer<Void>.self)
                    var val = CFDictionaryGetValue(properties, propertyKey)
                    if val != nil{
                        CFNumberGetValue(val as! CFNumber, CFNumberType.LongType, &height)
                    }
                    propertyKey = unsafeBitCast(kCGImagePropertyPixelWidth, UnsafePointer<Void>.self)
                    val = CFDictionaryGetValue(properties, propertyKey)
                    if val != nil{
                        CFNumberGetValue(val as! CFNumber, CFNumberType.LongType, &width)
                    }
                    propertyKey = unsafeBitCast(kCGImagePropertyOrientation, UnsafePointer<Void>.self)
                    val = CFDictionaryGetValue(properties, propertyKey)
                    if val != nil{
                        CFNumberGetValue(val as! CFNumber, CFNumberType.LongType, &orientationValue)
                    }
                    orientation = orientationFromPropertyValue(orientationValue == -1 ? 1 : orientationValue)
                }
            }
            
            if (width + height > 0 && totalSize < expectedSize){
                if #available(iOS 4.0, *){
                    if var partialImageRef = CGImageSourceCreateImageAtIndex(imageSource!, 0, nil){
                        let partialHeight = CGImageGetHeight(partialImageRef)
                        let colorSpace = CGColorSpaceCreateDeviceRGB()
                        
                        if let bmContext = CGBitmapContextCreate(nil, width, height, 8, 4 * width,colorSpace,CGBitmapInfo.ByteOrderDefault.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue){
                            CGContextDrawImage(bmContext, CGRectMake(0, 0, CGFloat(width), CGFloat(partialHeight)), partialImageRef)
                            partialImageRef = CGBitmapContextCreateImage(bmContext)!
                            
                        }
                        
                        var image = UIImage(CGImage: partialImageRef, scale: 1, orientation: orientation!)
                        //TODO:- WebImgaeManager
                        let key = ""
                        let scaledImage = scaleImageForKey(key, image: image)
                        if shouldDecompressImages{
                            ////TODO:- Decode
                        }else{
                            image = scaledImage
                        }
                        dispatch_main_sync_safe({
                            self.completionBlock?()
                        })
                    }
                }
            }
        }
        progressClosure?(receivedSize: imageData!.length,expectedSize: expectedSize)
    }
    
    func connectionDidFinishLoading(aconnection: NSURLConnection) {
        objc_sync_enter(self)
        CFRunLoopStop(CFRunLoopGetCurrent())
        thread = nil
        connection = nil
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.Stop, object: self)
            NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.Finish, object: self)
        }
        if NSURLCache.sharedURLCache().cachedResponseForRequest(request!) == nil{
            responseFromCached = false
        }
        if let closure = completedColsure{
            if options != nil && options == FTWebImageDownloaderOptions.IgnoreCachedResponse && responseFromCached{
                closure(image: nil,data: nil,error: nil,finished: true)
            }else if let imageData = imageData{
                //image = UIImage()
                var image = UIImage.ft_imageWithData(imageData)
                let key = FTWebImageManager.sharedManager.cacheKeyForURL(request!.URL!)
                image = scaleImageForKey(key, image: image!)
                if ((image?.images) == nil) {
                    if shouldDecompressImages {
                        image = UIImage.decodedImage(image!)
                    }
                }
                if CGSizeEqualToSize(image!.size, CGSizeZero) {
                    completedColsure?(image: nil,data: nil,error: NSError(domain: FTWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Downloaded image has 0 piexels"]),finished: true)
                }else{
                    completedColsure?(image: nil,data: imageData,error: nil,finished: true)
                }
            }else{
                    completedColsure?(image: nil,data: nil,error: NSError(domain: FTWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Image data is nil"]),finished: true)
            }
        }
        objc_sync_exit(self)
        completedColsure = nil
        done()
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        objc_sync_exit(self)
        CFRunLoopStop(CFRunLoopGetCurrent())
        thread = nil
        self.connection = nil
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(FTNotifications.Download.Stop, object: self)
        }
        objc_sync_exit(self)
    }
    
    func connection(connection: NSURLConnection, willCacheResponse cachedResponse: NSCachedURLResponse) -> NSCachedURLResponse? {
        responseFromCached = false
        if request?.cachePolicy == .ReloadIgnoringLocalCacheData{
            return nil
        }else {
            return cachedResponse
        }
    }
    
    func shouldContinueWhenAppEntersBackground() -> Bool {
        return options == FTWebImageDownloaderOptions.ContinueInBackground
    }
    
    func connectionShouldUseCredentialStorage(connection: NSURLConnection) -> Bool {
        return shouldUseCredentialStorage
    }
    
    func connection(connection: NSURLConnection, willSendRequestForAuthenticationChallenge challenge: NSURLAuthenticationChallenge) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust{
            if options != FTWebImageDownloaderOptions.AllowInvalidSSLCertificates {
                challenge.sender?.performDefaultHandlingForAuthenticationChallenge?(challenge)
            }else{
                let credential = NSURLCredential(trust: challenge.protectionSpace.serverTrust!)
                challenge.sender?.useCredential(credential, forAuthenticationChallenge: challenge)
            }
        }else{
            if challenge.previousFailureCount == 0{
                if credential != nil{
                    challenge.sender?.useCredential(credential!, forAuthenticationChallenge: challenge)
                }else{
                    challenge.sender?.continueWithoutCredentialForAuthenticationChallenge(challenge)
                }
            }else{
                challenge.sender?.continueWithoutCredentialForAuthenticationChallenge(challenge)
            }
        }
    }
}
