//
//  FTWebImageDefines.swift
//  FTWebImage
//
//  Created by Neo on 16/4/8.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit
import Foundation


/// params
typealias FTWebImageNoParamsClosure = () -> ()


/// Download
typealias FTWebImageDownloaderProgressClosure = (receivedSize : Int,expectedSize : Int) -> ()
typealias FTWebImageDownloaderCompletedClosure = (image : UIImage?,data : NSData?,error : NSError?,finished : Bool) -> ()
typealias FTWebImageDownloaderHeadersFilterClosure = (url : NSURL,headers : [String : String]) -> ([String : String])

typealias FTWebImageCompletedClosure = (image : UIImage?,error : NSError,cacheType : FTImageCacheType,imageURL : NSURL?) -> ()
typealias FTWebImageCompletionWithFinishedClosure = (image : UIImage?,error : NSError?,cacheType : FTImageCacheType,finished : Bool,imageURL : NSURL) -> ()
typealias FTWebImageCacheKeyFilterClosure = (url : NSURL) -> (String)

/// Cache
typealias FTWebImageQueryCompletedClosure = (image : UIImage?,cacheType : FTImageCacheType) -> ()
typealias FTWebImageCheckCacheCompletionClosure = (isInCache : Bool) -> ()
typealias FTWebImageCalculateSizeClosure = (fileCount : Int, totalSize : Int) -> ()

typealias FTWebImagePrefetcherProgressClosure = (noOfFinishedUrs : Int, noOfTotalUrls : Int) -> ()
typealias FTWebImagePrefetcherCompletionClosure = (noOfFinishedUrs : Int, noOfSkippedUrls : Int) -> ()

func dispatch_main_sync_safe(action : dispatch_block_t) {
    if NSThread.isMainThread() {
        action()
    }else{
        dispatch_sync(dispatch_get_main_queue(), action)
    }
}

func dispatch_main_async_safe(action : dispatch_block_t) {
    if NSThread.isMainThread() {
        action()
    }else{
        dispatch_async(dispatch_get_main_queue(), action)
    }
}


let FTWebImageErrorDomain = "FLWebImageErrorDomain"

public struct FTNotifications {
    public struct Download{
        public static let Start = "com.fltx.notificatios.start"
        public static let ReceiveResponse = "com.fltx.notificatios.receiveResponse"
        public static let Stop = "com.fltx.notificatios.stop"
        public static let Finish = "com.fltx.notificatios.finish"
    }
}

enum FTWebImageDownloaderOptions : Int{
    case LowPriority = 5000,ProgressiveDownload,UseNSURLCache,IgnoreCachedResponse,ContinueInBackground,HandleCookies,AllowInvalidSSLCertificates,HighPriority
}

enum FTWebImageOptions : Int{
    case RetryFailed = -6000,LowPriority,CacheMemoryOnly,ProgressiveDownload,RefreshCached,ContinueInBackground,HandleCookies,AllowInvalidSSLCertificates,HighPriority,DelayPlaceholder,TransformAnimatedImage,AvoidAutoSetImage
}


enum FTImageOptions : Int{
    case RetryFailed = -7000,LowPriority,CacheMemoryOnly,ProgressiveDownload,RefreshCached,ContinueInBackground,HandleCookies,AllowInvalidSSLCertificates,HighPriority,DelayPlaceholder,TransformAnimatedImage,AvoidAutoSetImage
}
