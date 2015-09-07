//
//  Helpers.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/8.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import MMAppSwitcher
import MBProgressHUD
import SDWebImage

let CurrentVersionKey = "kCurrentVersionKey"
let ClearCacheOnExitKey = "kClearCacheOnExitKey"
let ClearCacheNowKey = "kClearCacheNowKey"
let ClearDownloadCacheKey = "kClearDownloadCacheKey"
let ImageCacheSizeKey = "kImageCacheSizeKey"
let PasscodeLockStatus = "kPasscodeLockStatus"
let PasscodeLockConfig = "kPasscodeLockConfig"
let LastViewedSectionTitle = "kLastViewedSectionTitle"
let CurrentCLLinkKey = "kCurrentCLLinkKey"
let DaguerreForumID = 16

func getValue(key:String) -> AnyObject? {
    let defaults = NSUserDefaults.standardUserDefaults()
    return defaults.objectForKey(key)
}

func saveValue(value:AnyObject, forKey key:String) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setObject(value, forKey: key)
    defaults.synchronize()
}

func systemMajorVersion() -> Int {
    let ver = UIDevice.currentDevice().systemVersion
    let majorVersion = (ver.componentsSeparatedByString(".")[0] as NSString).integerValue
    return majorVersion
}

func userInterfaceIdiom() -> UIUserInterfaceIdiom {
    return UIDevice.currentDevice().userInterfaceIdiom
}

func showHUDInView(view:UIView, withMessage message: String, afterDelay delay:NSTimeInterval) -> MBProgressHUD {
    let messageHUD = MBProgressHUD.showHUDAddedTo(view, animated: true)
    messageHUD.mode = MBProgressHUDMode.CustomView
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
    let version = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
    let build = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as! String
    defaults.setObject("\(version)(\(build))", forKey:CurrentVersionKey)
    defaults.synchronize()
}

func userDocumentPath() -> String {
    let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] 
    return path
}

func localImagePath(link:String) -> String {
    let imageCache = SDImageCache.sharedImageCache()
    let key = SDWebImageManager.sharedManager().cacheKeyForURL(NSURL(string:link))
    let path = imageCache.defaultCachePathForKey(key)
    
    return path
}

func localDirectoryForPost(link:String, create:Bool = true) -> String? {
    let key = SDWebImageManager.sharedManager().cacheKeyForURL(NSURL(string:link))
    let hash = SDImageCache.sharedImageCache().cachePathForKey(key, inPath: "")
    let path = userDocumentPath().vc_stringByAppendingPathComponent(hash)
    let fm = NSFileManager.defaultManager()
    var isDir:ObjCBool = false
    guard let p = path else {
        return nil
    }
    let dirExists = fm.fileExistsAtPath(p, isDirectory: &isDir)
    if dirExists && !isDir {
        do {
            try fm.removeItemAtPath(p)
        }
        catch let error {
            print(error)
        }
    }
    else if !dirExists {
        if create {
            do {
                try fm.createDirectoryAtPath(p, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error {
                print(error)
            }
        }
        else {
            return nil
        }
    }
    
    return path
}

func saveCachedLinksToHomeDirectory(links:Array<String>, forPostLink postLink:String) {
    let fm = NSFileManager.defaultManager()
    for var i = 0; i < links.count; i++ {
        let imagePath = localImagePath(links[i])
        let destDir = localDirectoryForPost(postLink)!
        guard let destImageName = destDir.vc_stringByAppendingPathComponent("\(i + 1)") else {
            return
        }
        if fm.fileExistsAtPath(imagePath) && !fm.fileExistsAtPath(destImageName) {
            do {
                try fm.copyItemAtPath(imagePath, toPath: destImageName)
            } catch _ {

            }
        }
    }
}

func imagesCached(forPostLink link:String) -> Bool {
    if let targetDir = localDirectoryForPost(link, create: false) {
        let fm = NSFileManager.defaultManager()
        let numberOfFiles = (try! fm.contentsOfDirectoryAtPath(targetDir)).count
        return numberOfFiles > 0 ? true : false
    }
    else {
        return false
    }
}

func siteLinks(forumID:Int) -> [String] {
    return baseLink(forumID).componentsSeparatedByString(";")
}

func getDaguerreLink(forumID:Int) -> String {
    if forumID == DaguerreForumID {
        let link = getValue(CurrentCLLinkKey) as! String?
        if let l = link {
            let clearedLink = l.stringByReplacingOccurrencesOfString("(科学上网)", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch, range: Range(start: l.startIndex, end: l.endIndex))
            return clearedLink
        }
        else {
            let links = siteLinks(DaguerreForumID)
            var l = links[0]
            l = l.stringByReplacingOccurrencesOfString("(科学上网)", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch, range: Range(start: l.startIndex, end: l.endIndex))
            if link == nil {
                saveValue(l, forKey: CurrentCLLinkKey)
            }
            return l
        }
    }
    else {
        return baseLink(forumID)
    }
}

extension NSData {
    func stringFromGB18030Data() -> String {
        // CP 936: GBK, CP 54936: GB18030
        let cfEncoding = CFStringConvertWindowsCodepageToEncoding(54936) //GB18030
        let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return NSString(data: self, encoding: gbkEncoding)! as String
    }
}

extension String {
    func vc_stringByAppendingPathComponent(component : String) -> String? {
        guard let url = NSURL(string: self) else {
            return nil
        }
        return url.URLByAppendingPathComponent(component).absoluteString
    }
}
