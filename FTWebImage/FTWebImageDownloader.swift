//
//  FTWebImageDownloader.swift
//  Test
//
//  Created by Neo on 16/4/8.
//  Copyright © 2016年 XM. All rights reserved.
//


import Foundation

enum FTWebImageDownloaderExecutionOrder{
    case FIFOExecutionOrder,LIFOExecutionOrder
}

class FTWebImageDownloader: NSObject {
    
    static let sharedDownloader = FTWebImageDownloader()
    var shouldDecompressImages = true
    var maxConcurrentDownloads : Int{
        get{
            return downloadQueue.maxConcurrentOperationCount
        }
        set{
            downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
        }
    }
    var currentDownloadCount : Int {
        get{
            return downloadQueue.operationCount
        }
    }
    private var lastAddedOperation : NSOperation?
    var downloadTimeout : NSTimeInterval?
    var executionOrder : FTWebImageDownloaderExecutionOrder = .FIFOExecutionOrder
    var urlCredential : NSURLCredential?
    var username,password : String?
    var headersFilter : FTWebImageDownloaderHeadersFilterClosure?
    var urlCallbacks = NSMutableDictionary()
    var downloadQueue = NSOperationQueue()
    var HTTPHeaders : [String : String] = ["Accept" : "image/webp,image/*;q=0.8"]
    var barrierQueue = dispatch_queue_create("com.hackemist.FTWebImageDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT)
    private let kProgressCallbackKey = "progress"
    private let kCompletedCallbackKey = "completed"
    override init(){
        super.init()
        downloadQueue.maxConcurrentOperationCount = 6
        downloadTimeout = 15
    }
    
    deinit{
        downloadQueue.cancelAllOperations()
    }
    
    func setValue(value : String?,forHTTPHeaderField field : String){
        if value != nil {
            HTTPHeaders[field] = value!
        }else{
            HTTPHeaders.removeValueForKey(field)
        }
    }
    
    func valueForHTTPHeaderField(field : String) -> String {
        return HTTPHeaders[field]!
    }
    
    func maxConcurrentDownloads(maxConcurrentDownloads : Int) {
        downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
    }
    
    func downloadImageWithURL(url : NSURL,options : FTWebImageDownloaderOptions,progress progressClosure : FTWebImageDownloaderProgressClosure,completed : FTWebImageDownloaderCompletedClosure) -> FTWebImageOperation{
        var operation : FTImageDownloaderOperation!
        addProgressCallback(progressClosure, completeClosure: completed, url: url) {[weak self] () -> () in
            if let strongSelf = self{
                var timeoutInterval = strongSelf.downloadTimeout
                if timeoutInterval == 0{
                    timeoutInterval = 15
                }
                let request = NSMutableURLRequest(URL: url, cachePolicy: (options == .UseNSURLCache ? .ReloadIgnoringLocalCacheData : .UseProtocolCachePolicy), timeoutInterval: timeoutInterval!)
                request.HTTPShouldHandleCookies = options == .HandleCookies
                request.HTTPShouldUsePipelining = true
                if (strongSelf.headersFilter != nil){
                    request.allHTTPHeaderFields = strongSelf.headersFilter!(url : url,headers : strongSelf.HTTPHeaders)
                }else{
                    request.allHTTPHeaderFields = strongSelf.HTTPHeaders
                }
                
                operation = FTImageDownloaderOperation(request: request, options: options, progress: {(receivedSize, expectedSize) -> () in
                    var callbacksForURL : NSArray!
                    dispatch_sync(strongSelf.barrierQueue, { () -> Void in
                        callbacksForURL = strongSelf.urlCallbacks[url] as! NSArray
                    })
                    for callbacks in callbacksForURL{
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            //   if let callback = callbacks[self.kProgressCallbackKey]{
                            //   callback(rece)
                        })
                    }
                    }, completed: { (image, data, error, finished) -> () in
                        var callbacksForURL : NSArray!
                        dispatch_sync(strongSelf.barrierQueue, { () -> Void in
                            callbacksForURL = strongSelf.urlCallbacks[url] as! NSArray
                            if finished{
                                strongSelf.urlCallbacks.removeObjectForKey(url)
                            }
                        })
                    }, cancelled: { () -> () in
                        dispatch_sync(strongSelf.barrierQueue, { () -> Void in
                            strongSelf.urlCallbacks.removeObjectForKey(url)
                        })
                })
                operation.shouldDecompressImages = strongSelf.shouldDecompressImages
                if (strongSelf.urlCredential != nil){
                    operation.credential = strongSelf.urlCredential
                }else if strongSelf.username != nil && strongSelf.password != nil{
                    operation.credential = NSURLCredential(user: strongSelf.username!, password: strongSelf.password!, persistence: .ForSession)
                }
                if options == .HighPriority{
                    operation.queuePriority = .High
                }else if options == .LowPriority{
                    operation.queuePriority = .Low
                }
                strongSelf.downloadQueue.addOperation(operation)
                if strongSelf.executionOrder == .LIFOExecutionOrder{
                    strongSelf.lastAddedOperation?.addDependency(operation)
                    strongSelf.lastAddedOperation = operation
                }
            }
        }
        return operation
    }
    
    func addProgressCallback(progressClosure : FTWebImageDownloaderProgressClosure?,completeClosure : FTWebImageDownloaderCompletedClosure?,url : NSURL?,createCallBack : FTWebImageNoParamsClosure?) {
        if url == nil{
            completeClosure?(image: nil, data: nil, error: nil, finished: false)
            return
        }
        dispatch_barrier_sync(barrierQueue) { () -> Void in
            var first = false
            if (self.urlCallbacks[url!] == nil){
                self.urlCallbacks[url!] = NSMutableArray()
                first = true
            }
            let callBacksForURL = self.urlCallbacks[url!]
            var callBacks = NSMutableDictionary()
            //            if (progressClosure != nil){
            //                callBacks.setValue(progressClosure, forKey: self.kProgressCallbackKey)
            //            }
            //            if completeClosure != nil{
            //                callBacks[kCompletedCallbackKey] = completeClosure!
            //            }
            callBacksForURL?.addObject(callBacks)
            self.urlCallbacks[url!] = callBacksForURL!
            if first{
                createCallBack?()
            }
        }
    }
    
    func setSuspended(suspended : Bool) -> Void {
        downloadQueue.suspended = suspended
    }
    
}
