//
//  Helpers.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/8.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit

let CurrentVersionKey = "kCurrentVersionKey"
let ClearCacheOnExitKey = "kClearCacheOnExitKey"
let ClearCacheNowKey = "kClearCacheNowKey"
let ImageCacheSizeKey = "kImageCacheSizeKey"
let PasscodeLockStatus = "kPasscodeLockStatus"
let PasscodeLockConfig = "kPasscodeLockConfig"

func showHUDInView(view:UIView, withMessage message: String, afterDelay delay:NSTimeInterval) -> MBProgressHUD {
    var messageHUD = MBProgressHUD.showHUDAddedTo(view, animated: true)
    messageHUD.mode = MBProgressHUDModeCustomView
    messageHUD.labelText = message
    if delay != 0.0 {
        messageHUD.hide(true, afterDelay: delay)
    }
    return messageHUD
}

func localizedString(key:String, comment:String) -> String {
    return NSLocalizedString(key, tableName: nil, value: key, comment: comment)
}

func updateVersionNumber() {
    let defaults = NSUserDefaults.standardUserDefaults()
    let version = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as String
    let build = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as String
    defaults.setObject("\(version)(\(build))", forKey:CurrentVersionKey)
    defaults.synchronize()
}
