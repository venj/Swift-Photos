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
let LastViewedSectionTitle = "kLastViewedSectionTitle"

func systemMajorVersion() -> Int {
    let ver:NSString = UIDevice.currentDevice().systemVersion as NSString
    let majorVersion = (ver.componentsSeparatedByString(".")[0] as NSString).integerValue
    return majorVersion
}

func userInterfaceIdiom() -> UIUserInterfaceIdiom {
    return UIDevice.currentDevice().userInterfaceIdiom
}

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

func userDocumentPath() -> String {
    let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
    return path
}

func localImagePath(link:String) -> String {
    let imageCache = SDImageCache.sharedImageCache()
    let key = SDWebImageManager.sharedManager().cacheKeyForURL(NSURL(string:link))
    let path = imageCache.defaultCachePathForKey(key)
    
    return path
}

func localDirectoryForPost(link:String) -> String {
    let key = SDWebImageManager.sharedManager().cacheKeyForURL(NSURL(string:link))
    let hash = SDImageCache.sharedImageCache().cachePathForKey(key, inPath: "")
    let path = (userDocumentPath() as NSString).stringByAppendingPathComponent(hash)
    let fm = NSFileManager.defaultManager()
    var isDir:ObjCBool = false
    let dirExists = fm.fileExistsAtPath(path, isDirectory: &isDir)
    if dirExists && !isDir {
        fm.removeItemAtPath(path, error: nil)
    }
    else if !dirExists {
        fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil, error: nil)
    }
    
    return path
}

func saveCachedLinksToHomeDirectory(links:Array<String>, forPostLink postLink:String) {
    let fm = NSFileManager.defaultManager()
    for link in links {
        fm.copyItemAtPath(localImagePath(link), toPath: localDirectoryForPost(postLink), error: nil)
    }
}
