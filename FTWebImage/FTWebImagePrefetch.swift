

//
//  FTWebImagePrefetch.swift
//  FTWebImage
//
//  Created by Neo on 16/5/12.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit

@objc protocol FTWebImagePrefetchrDelegate{
    
    optional func imagePrefetch(imagePrefetch : FTWebImagePrefetchr,imageURL : NSURL,finishedCount : Int,totalCount : Int)
    optional func imagePrefetch(imagePrefetch : FTWebImagePrefetchr,totalCount : Int,skippedCount : Int)
    
}

class FTWebImagePrefetchr: NSObject {
    
    static let sharedImagePrefetcher = FTWebImagePrefetchr()
    var maxConcurrentDownloads : Int = 3
    var options : FTWebImageOptions = .LowPriority
    var prefetcherQueue : dispatch_queue_t = dispatch_get_main_queue()
    var delegate : FTWebImagePrefetchrDelegate?
    
    private var manager : FTWebImageManager!
    private var prefetchURLs : NSArray!
    private var requestedCount : Int = 0
    private var skippedCount : Int = 0
    private var finishedCount : Int = 0
    private var startedTime : NSTimeInterval!
    private var completionClosure : FTWebImagePrefetcherCompletionClosure!
    private var progressClosure : FTWebImagePrefetcherProgressClosure!
    
    override init() {
        super.init()
    }
    
    convenience init(manager : FTWebImageManager) {
        self.init()
        self.manager = manager
    }
    
    func setMaxCocurrentDownloads(maxCocurrentDownloads : Int) {
        manager.imageDownloader.maxConcurrentDownloads = maxConcurrentDownloads
    }
    
    func getMaxConcurrentDownloads() -> Int {
        return manager.imageDownloader.maxConcurrentDownloads
    }
    
    func startPrefetchingAtIndex(index : Int) {
        if index >= prefetchURLs.count {
            return
        }
        requestedCount += 1
        manager.downloadImageWithURL(prefetchURLs[index] as! NSURL, options: self.options, progressClosure: nil) { (image, error, cacheType, finished, imageURL) in
            if !finished{
                return
            }
            self.finishedCount += 1
            self.progressClosure?(noOfFinishedUrs: self.finishedCount,noOfTotalUrls: self.prefetchURLs.count)
            if (image == nil){
                self.skippedCount += 1
            }
            self.delegate?.imagePrefetch?(self, imageURL: self.prefetchURLs[index] as! NSURL, finishedCount: self.finishedCount, totalCount: self.prefetchURLs.count)
            if self.prefetchURLs.count > self.requestedCount{
                dispatch_async(self.prefetcherQueue, {
                    self.startPrefetchingAtIndex(self.requestedCount)
                })
            }else if self.finishedCount == self.requestedCount{
                self.reportStatus()
                self.completionClosure?(noOfFinishedUrs: self.finishedCount,noOfSkippedUrls: self.skippedCount)
                self.completionClosure = nil
                self.progressClosure = nil
            }
        }
    }
    
    func reportStatus(){
        let total = self.prefetchURLs.count
        self.delegate?.imagePrefetch?(self, totalCount: (total - self.skippedCount), skippedCount: self.skippedCount)
    }
    
    func prefetchURLs(urls : NSArray){
        prefetchWithURLs(urls, progressClosure: nil, completionClosure: nil)
    }
    
    func prefetchWithURLs(urls : NSArray,progressClosure : FTWebImagePrefetcherProgressClosure?,completionClosure : FTWebImagePrefetcherCompletionClosure?){
        cancelPrefetching()
        startedTime = CFAbsoluteTimeGetCurrent()
        prefetchURLs = urls
        self.completionClosure = nil
        self.progressClosure = nil
        if urls.count == 0 {
            completionClosure?(noOfFinishedUrs: 0,noOfSkippedUrls: 0)
        }else{
            let listCount = self.prefetchURLs.count
            for i in 0..<listCount{
                startPrefetchingAtIndex(i)
            }
        }
    }
    
    func cancelPrefetching(){
        prefetchURLs = nil
        skippedCount = 0
        requestedCount = 0
        finishedCount = 0
        manager.cancelAll()
    }
}