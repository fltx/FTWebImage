

//
//  FTWebImageManager.swift
//  Test
//
//  Created by Neo on 16/4/28.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit

func synchronized(lockObject: AnyObject, closure: () -> ()){
    objc_sync_enter(lockObject)
    closure()
    objc_sync_exit(lockObject)
}

class FTWebImageCombinedOperation : NSObject,FTWebImageOperation{
    
    private var _isCancelled = false
    var isCancelled : Bool{
        get{
            return _isCancelled
        }
    }
    
    var cancelClosure : FTWebImageNoParamsClosure?
    var cacheOperation : NSOperation?
    func setCancelBlock(_cancelClosure : FTWebImageNoParamsClosure?) {
        if isCancelled{
            if let cancelClosure = _cancelClosure {
                cancelClosure()
            }
            cancelClosure = nil
        }else{
            cancelClosure = _cancelClosure
        }
    }
    
    func cancel() {
        _isCancelled = true
        if cacheOperation != nil{
            cacheOperation!.cancel()
            cacheOperation = nil
        }
        if cancelClosure != nil{
            cancelClosure!()
            cancelClosure = nil
        }
    }
}

@objc protocol FTWebImageManagerDelegate{
    optional func imageManager(manager : FTWebImageManager,shouldDownloadImgeForURL imageURL : NSURL) -> Bool
    func imageManager(manager : FTWebImageManager,transformDownloadedImage image : UIImage, imageURL : NSURL) -> UIImage?
}

class FTWebImageManager: NSObject {
    static let sharedManager = FTWebImageManager()
    weak var delegate : FTWebImageManagerDelegate?
    private(set) var imageCache = FTImageCache.sharedImageCache
    private(set) var imageDownloader = FTWebImageDownloader.sharedDownloader
    var cacheKeyFilter : FTWebImageCacheKeyFilterClosure?
    private var failedURLs = NSMutableSet()
    private var runningOperations = [FTWebImageCombinedOperation]()
    override init()
    {
        super.init()
    }
    
    func cacheKeyForURL(url : NSURL) -> String {
        return cacheKeyFilter?(url: url) ?? url.absoluteString
    }
    
    func cachedImageExistsForURL(url : NSURL) -> Bool{
        let key = cacheKeyForURL(url)
        if imageCache.imageFromMemoryCacheForKey(key) != nil
        {
            return true
        }
        return imageCache.diskImageExistsWithKey(key)
    }
    
    func diskImageExisForURL(url : NSURL) -> Bool {
        return imageCache.diskImageExistsWithKey(cacheKeyForURL(url))
    }
    
    func cachedImageExistsForURL(url : NSURL,completion completionClosure : FTWebImageCheckCacheCompletionClosure?){
        let key = cacheKeyForURL(url)
        let isInMemory = imageCache.imageFromMemoryCacheForKey(key) != nil
        if isInMemory{
            dispatch_async(dispatch_get_main_queue(), {
                if let completionClosure = completionClosure{
                    completionClosure(isInCache: true)
                }
            })
            return
        }
        
        imageCache.diskImgaeExistsWithKey(key) { (isInCache) in
            if let completionClosure = completionClosure{
                completionClosure(isInCache: isInCache)
            }
        }
    }
    
    func diskImageExistsForURL(url : NSURL,completionClosure : FTWebImageCheckCacheCompletionClosure?) {
        let key = cacheKeyForURL(url)
        imageCache.diskImgaeExistsWithKey(key) { (isInCache) in
            if let completionClosure = completionClosure{
                completionClosure(isInCache: isInCache)
            }
        }
    }
    
    func downloadImageWithURL(url : NSURL,options : FTWebImageOptions,progressClosure : FTWebImageDownloaderProgressClosure?, completionClosure : FTWebImageCompletionWithFinishedClosure) -> FTWebImageOperation {
        let operation = FTWebImageCombinedOperation()
        var isFailedUrl = false
        objc_sync_enter(failedURLs)
        isFailedUrl = failedURLs.containsObject(url)
        objc_sync_exit(failedURLs)
        
        if url.absoluteString.length == 0 || options == .RetryFailed && isFailedUrl{
            dispatch_main_sync_safe({
                let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: nil)
                completionClosure(image: nil,error: error,cacheType:FTImageCacheType.None,finished:true,imageURL: url)
            })
            return operation
        }
        
        objc_sync_enter(runningOperations)
        runningOperations.append(operation)
        objc_sync_exit(runningOperations)
        let key = cacheKeyForURL(url)
        operation.cacheOperation = imageCache.queryDiskCacheForKey(key, doneClosure: {[unowned self] (image, cacheType) in
            if operation.isCancelled{
                objc_sync_enter(self.runningOperations)
                self.runningOperations.remove(operation)
                objc_sync_exit(self.runningOperations)
                return
            }
            
            if (image != nil || options == .RefreshCached) && (self.delegate == nil || self.delegate!.imageManager!(self, shouldDownloadImgeForURL: url)){
                if image != nil && options == .RefreshCached{
                    dispatch_main_sync_safe({
                        completionClosure(image: image!,error:nil, cacheType:cacheType,finished:true, imageURL: url)
                    })
                }
                var downloadOptions : FTWebImageDownloaderOptions = .LowPriority
                if options == .LowPriority{
                    downloadOptions = .LowPriority
                }
                if options == .ProgressiveDownload{
                    downloadOptions = .ProgressiveDownload
                }
                if options == .RefreshCached{
                    downloadOptions = .UseNSURLCache
                }
                if options == .ContinueInBackground{
                    downloadOptions = .ContinueInBackground
                }
                if options == .HandleCookies{
                    downloadOptions = .HandleCookies
                }
                if options == .AllowInvalidSSLCertificates{
                    downloadOptions = .AllowInvalidSSLCertificates
                }
                if options == .HighPriority{
                    downloadOptions = .HighPriority
                }
                if image != nil && options == .RefreshCached{
                    downloadOptions = .IgnoreCachedResponse
                }
                
                let subOperation = self.imageDownloader.downloadImageWithURL(url, options: downloadOptions, progress: progressClosure!, completed: { (downloadImage, data, error, finished) in
                    if operation.isCancelled{
                        // Do nothing if the operation was cancelled
                        // See #699 for more details
                        // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                    }else if let error = error{
                        dispatch_main_sync_safe({
                            if operation.isCancelled{
                                completionClosure(image: nil, error: error, cacheType: .None, finished: finished, imageURL: url)
                            }
                        })
                        
                        if (error.code != NSURLErrorNotConnectedToInternet
                            && error.code != NSURLErrorCancelled
                            && error.code != NSURLErrorTimedOut
                            && error.code != NSURLErrorInternationalRoamingOff
                            && error.code != NSURLErrorDataNotAllowed
                            && error.code != NSURLErrorCannotFindHost
                            && error.code != NSURLErrorCannotConnectToHost){
                            objc_sync_enter(self.failedURLs)
                            self.failedURLs.addObject(url)
                            objc_sync_exit(self.failedURLs)
                        }
                    }else{
                        if options == .RetryFailed{
                            objc_sync_enter(self.failedURLs)
                            self.failedURLs.removeObject(url)
                            objc_sync_exit(self.failedURLs)
                        }
                        let cacheOnDisk = (options.rawValue != FTImageOptions.CacheMemoryOnly.rawValue)
                        if options.rawValue == FTWebImageOptions.RefreshCached.rawValue && image != nil && downloadImage != nil{
                            // Image refresh hit the NSURLCache cache, do not call the completion block
                        }else if downloadImage != nil && (downloadImage!.images == nil || options.rawValue == FTImageOptions.TransformAnimatedImage.rawValue) && self.delegate != nil{
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
                                let transfromedImage = self.delegate!.imageManager(self, transformDownloadedImage: downloadImage!, imageURL: url)
                                if transfromedImage != nil && finished{
                                    let imageWasTransformed = transfromedImage!.isEqual(downloadImage!)
                                    self.imageCache.storeImage(transfromedImage!, recalculateFromImage: imageWasTransformed, imageData: imageWasTransformed ? nil : data, key: key, toDisk: cacheOnDisk)
                                }
                                dispatch_main_sync_safe({
                                    if !operation.isCancelled{
                                        completionClosure(image: transfromedImage, error: nil, cacheType: .None, finished: finished, imageURL: url)
                                    }
                                })
                            })
                        }else{
                            if downloadImage != nil && finished{
                                self.imageCache.storeImage(downloadImage!, recalculateFromImage: false, imageData: data, key: key, toDisk: cacheOnDisk)
                            }
                            dispatch_main_sync_safe({
                                if !operation.isCancelled{
                                    completionClosure(image: downloadImage, error: nil, cacheType: .None, finished: finished, imageURL: url)
                                }
                            })
                        }
                    }
                    
                    if finished{
                        objc_sync_enter(self.runningOperations)
                        self.runningOperations.remove(operation)
                        objc_sync_exit(self.runningOperations)
                    }
                })
                
                operation.cancelClosure = {
                    operation.cancel()
                    objc_sync_enter(self.runningOperations)
                    self.runningOperations.remove(operation)
                    objc_sync_exit(self.runningOperations)
                }
            }else if image != nil{
                dispatch_main_sync_safe({
                    if !operation.isCancelled{
                        completionClosure(image: image, error: nil, cacheType: cacheType, finished: true, imageURL: url)
                    }
                })
                objc_sync_enter(self.runningOperations)
                self.runningOperations.remove(operation)
                objc_sync_exit(self.runningOperations)
            }else{
                dispatch_main_sync_safe({
                    if !operation.isCancelled{
                        completionClosure(image: nil, error: nil, cacheType: .None, finished: true, imageURL: url)
                    }
                })
                
                synchronized(self.runningOperations){
                    self.runningOperations.remove(operation)
                }
             }
        })
        return operation
    }
    
    func saveImageToCache(image : UIImage,url : NSURL) {
        let key = cacheKeyForURL(url)
        imageCache.storeImage(image, key: key, toDisk: true)
    }
    
    func cancelAll(){
        synchronized(runningOperations) {
            for operation in self.runningOperations{
                operation.cancel()
            }
            self.runningOperations.removeAll()
        }
    }
    
    func isRunning() -> Bool{
        var running = false
        synchronized(runningOperations) {
            running = self.runningOperations.count > 0
        }
        return running
    }
}


