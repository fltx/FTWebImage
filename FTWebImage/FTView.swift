//
//  FTView.swift
//  Test
//
//  Created by Neo on 16/4/14.
//  Copyright © 2016年 XM. All rights reserved.
//

import UIKit


extension UIView{
    /**
     Keys used for associated objects.
     */
    private struct FTViewKeys {
        static var loadOperationKey = "FTLoadOperationKey"
    }
    
    func operationDictionary() -> NSMutableDictionary {
        if let operations = objc_getAssociatedObject(self, &FTViewKeys.loadOperationKey){
            return operations as! NSMutableDictionary
        }
        let operations = NSMutableDictionary()
        objc_setAssociatedObject(self, &FTViewKeys.loadOperationKey, operations, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return operations
    }
    
    func ft_setImageLoadOperation(operation : AnyObject,key : String) {
        ft_cancelImageLoadOperationWithKey(key)
        let operationDictionary = self.operationDictionary()
        operationDictionary.setObject(operation, forKey: key)
    }
    
    func ft_cancelImageLoadOperationWithKey(key : String) {
        let operationDictionary = self.operationDictionary()
        if let operations = operationDictionary.objectForKey(key)
        {
            if operations is NSArray{
                let operationsArray = operations as! NSArray
                for operation in operationsArray{
                    (operation as! FTWebImageOperation).cancel()
                }
            }else{
                (operations as? FTWebImageOperation)?.cancel()
            }
            operationDictionary.removeObjectForKey(key)
        }
    }
    
    func ft_removeImgaeLoadOperationWithKey(key : String){
        let operationDictionary = NSMutableDictionary()
        operationDictionary.removeObjectForKey(key)
    }
}
