//
//  FTImageView.swift
//  FTWebImage
//
//  Created by Neo on 16/4/15.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit
import Foundation

let FTImageViewHighlightedWebCacheOperationKey = "HighlightedWebCacheOperationKey"

/**
 Keys used for associated objects.
 */
private struct FTImageViewKeys {
    static var ImageURLKey                  = "FTImageURLKey"
    static var TAG_ACTIVITY_INDICATOR       = "FTTAG_ACTIVITY_INDICATOR"
    static var TAG_ACTIVITY_STYLE           = "FTTAG_ACTIVITY_STYLE"
    static var TAG_ACTIVITY_SHOW            = "FTTAG_ACTIVITY_SHOW"
}


// MARK: - HighlightedWebCache
extension UIImageView{
    func ft_setHighlightedImageWithURL(url : NSURL){
        ft_setHighlightImageWithURL(url, options: .RetryFailed, progressClosure: nil, completeClosure: nil)
    }
    
    func ft_setHighlightedImageWithURL(url : NSURL,options : FTWebImageOptions) {
        ft_setHighlightImageWithURL(url, options: options, progressClosure: nil, completeClosure: nil)
    }
    
    func ft_setHighlightedImageWithURL(url : NSURL,completedClosure : FTWebImageCompletedClosure){
        ft_setHighlightImageWithURL(url, options: .RetryFailed, progressClosure: nil, completeClosure: completedClosure)
    }
    
    func ft_setHighlightedImageWithURL(url : NSURL,options : FTWebImageOptions,completedClosure : FTWebImageCompletedClosure) {
        ft_setHighlightImageWithURL(url, options: options, progressClosure: nil, completeClosure: completedClosure)
    }
    
    func ft_setHighlightImageWithURL(url : NSURL?,options : FTWebImageOptions,progressClosure : FTWebImageDownloaderProgressClosure?,completeClosure : FTWebImageCompletedClosure?) {
        ft_cancelCurrentHighlightImageLoad()
        if let url = url{
            let operation = FTWebImageManager.sharedManager.downloadImageWithURL(url, options: options, progressClosure: progressClosure, completionClosure: { [weak self](image, error, cacheType, finished, imageURL) in
                if let strongSelf = self{
                    dispatch_main_sync_safe({
                        if image != nil  && options == FTWebImageOptions.AvoidAutoSetImage {
                            completeClosure?(image: image,error: error,cacheType: cacheType,imageURL: url)
                            return
                        }else if image != nil{
                            strongSelf.highlightedImage = image
                            strongSelf.setNeedsLayout()
                        }
                        if finished{
                            completeClosure?(image: image,error: error,cacheType: cacheType,imageURL: url)
                        }
                    })
                }
                })
            ft_setImageLoadOperation(operation, key: FTImageViewHighlightedWebCacheOperationKey)
        }else{
            let error = NSError(domain: FTWebImageErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Image data is nil"])
            completeClosure?(image: nil,error: error,cacheType:.None,imageURL: url)
        }
    }
    
    func ft_cacelCurrentHighlightedImageLoad() {
        ft_cancelImageLoadOperationWithKey(FTImageViewHighlightedWebCacheOperationKey)
    }
}


// MARK: - WebCache
extension UIImageView{
    
    func ft_setImageWithURL(url : NSURL)  {
        ft_setImageWithURL(url, placeholder: nil, options: .RetryFailed, progressClosure: nil, completedClosure: nil)
    }
    
    func ft_setimageWithURL(url : NSURL,placeholder : UIImage,options : FTWebImageOptions) {
        ft_setImageWithURL(url, placeholder: placeholder, options: options, progressClosure: nil, completedClosure: nil)
    }
    
    func ft_setImageWithURL(url : NSURL,completedClosure : FTWebImageCompletedClosure){
        ft_setImageWithURL(url, placeholder: nil, options: .RetryFailed, progressClosure: nil, completedClosure: completedClosure)
    }
    
    func ft_setImageWithURL(url : NSURL,placeholder : UIImage,completedClosure : FTWebImageCompletedClosure){
        ft_setImageWithURL(url, placeholder: placeholder, options: .RetryFailed, progressClosure: nil, completedClosure: completedClosure)
    }
    
    func st_setImageWithURL(url : NSURL,placeholder : UIImage,options : FTWebImageOptions,completedClosure : FTWebImageCompletedClosure) {
        ft_setImageWithURL(url, placeholder: placeholder, options: options, progressClosure: nil, completedClosure: completedClosure)
    }
    
    func ft_setImageWithURL(url : NSURL?,placeholder : UIImage?,options : FTWebImageOptions,progressClosure : FTWebImageDownloaderProgressClosure?,completedClosure : FTWebImageCompletedClosure?) {
        ft_cancelCurrentImageLoad()
        objc_setAssociatedObject(self, &FTImageViewKeys.ImageURLKey, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if options != .DelayPlaceholder{
            dispatch_main_async_safe({
                self.image = placeholder
            })
        }
        if let url = url {
            let operation = FTWebImageManager.sharedManager.downloadImageWithURL(url, options: options, progressClosure: progressClosure, completionClosure: { [weak self](image, error, cacheType, finished, imageURL) in
                if let strongSelf = self{
                    dispatch_main_sync_safe({
                        if image != nil && options == .AvoidAutoSetImage{
                            completedClosure?(image: image!, error: error!, cacheType: cacheType, imageURL: url)
                            return
                        }else if image != nil{
                            strongSelf.image = image
                            strongSelf.setNeedsLayout()
                        }else{
                            if options == .DelayPlaceholder{
                                strongSelf.image = placeholder
                                strongSelf.setNeedsLayout()
                            }
                        }
                        if finished{
                            completedClosure?(image: image!, error: error!, cacheType: cacheType, imageURL: url)
                        }
                    })
                }
                })
            ft_setImageLoadOperation(operation, key: "UIImageViewImageLoad")
        }else{
            dispatch_main_async_safe({
                completedClosure?(image: nil, error: NSError(domain: FTWebImageErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey : "Trying to load a nil url"]), cacheType: .None, imageURL: url)
            })
        }
    }
    
    func ft_setImageWithPreviousCachedImageWithURL(url : NSURL,placeholder : UIImage,options : FTWebImageOptions,progressClosure : FTWebImageDownloaderProgressClosure,completedClosure : FTWebImageCompletedClosure) {
        let key = FTWebImageManager.sharedManager.cacheKeyForURL(url)
        let lastPreviousCacheImage = FTImageCache.sharedImageCache.imageFromDiskCacheForKey(key)
        ft_setImageWithURL(url, placeholder: lastPreviousCacheImage != nil ? lastPreviousCacheImage : placeholder, options: options, progressClosure:
            progressClosure, completedClosure: completedClosure)
    }
    
    func ft_setAnimationImagesWithURLs(arrayOfURLs : [NSURL]) {
        ft_cancelCurrentAnimationImagesLoads()
        let operations = NSMutableArray()
        for logoImageURL in arrayOfURLs{
            let operation = FTWebImageManager.sharedManager.downloadImageWithURL(logoImageURL, options: .RetryFailed, progressClosure: nil, completionClosure: {[weak self] (image, error, cacheType, finished, imageURL) in
                if let strongSelf = self{
                    dispatch_main_sync_safe({
                        strongSelf.stopAnimating()
                        if image != nil{
                            var currentImages = strongSelf.animationImages
                            if currentImages == nil{
                                currentImages = [UIImage]()
                            }
                            currentImages!.append(image!)
                            strongSelf.animationImages = currentImages
                            strongSelf.setNeedsLayout()
                        }
                        strongSelf.startAnimating()
                    })
                }
                })
            operations.addObject(operation)
        }
        ft_setImageLoadOperation(operations, key: "UIImageViewAnimationImages")
    }
    
    func ft_imageURL() -> NSURL {
        return objc_getAssociatedObject(self, &FTImageViewKeys.ImageURLKey) as! NSURL
    }
    
    func ft_cancelCurrentHighlightImageLoad(){
        ft_cancelImageLoadOperationWithKey(FTImageViewHighlightedWebCacheOperationKey)
    }
    
    func ft_cancelCurrentImageLoad() {
        ft_cancelImageLoadOperationWithKey("UIImageViewImageLoad")
    }
    
    func ft_cancelCurrentAnimationImagesLoads(){
        ft_cancelImageLoadOperationWithKey("UIImageViewAnimationImages")
    }
}