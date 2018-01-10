//
//  Helpers.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/8.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import MMAppSwitcher
import SDWebImage
import PKHUD

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

func getValue(_ key:String) -> Any? {
    let defaults = UserDefaults.standard
    return defaults.object(forKey: key)
}

func saveValue(_ value: Any, forKey key:String) {
    let defaults = UserDefaults.standard
    defaults.set(value, forKey: key)
    defaults.synchronize()
}

func userInterfaceIdiom() -> UIUserInterfaceIdiom {
    return UIDevice.current.userInterfaceIdiom
}

func showHUD() -> PKHUD {
    let hud = PKHUD.sharedHUD
    hud.contentView = PKHUDProgressView()
    hud.show()
    return hud
}

func updateVersionNumber() {
    let defaults = UserDefaults.standard
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    defaults.set("\(version)(\(build))", forKey:CurrentVersionKey)
    defaults.synchronize()
}

func userDocumentPath() -> String {
    let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] 
    return path
}

func localImagePath(_ link:String) -> String {
    let imageCache = SDImageCache.shared()
    let key = SDWebImageManager.shared().cacheKey(for: URL(string:link))
    let path = imageCache.defaultCachePath(forKey: key)
    
    return path!
}

func localDirectoryForPost(_ link:String, create:Bool = true) -> String? {
    let host = URL(string: link)!.host!
    let placeHolderLink = link.replacingOccurrences(of: host, with: "example.com")
    let key = SDWebImageManager.shared().cacheKey(for: URL(string: placeHolderLink))
    let hash = SDImageCache.shared().cachePath(forKey: key, inPath: "")
    let path = userDocumentPath().vc_stringByAppendingPathComponent(hash!)
    let fm = FileManager.default
    var isDir:ObjCBool = false
    let dirExists = fm.fileExists(atPath: path, isDirectory: &isDir)

    if dirExists && !(isDir.boolValue) {
        do {
            try fm.removeItem(atPath: path)
        }
        catch let error {
            print(error)
        }
    }
    else if !dirExists {
        if create {
            do {
                try fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
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

func saveCachedLinksToHomeDirectory(_ links:[String], forPostLink postLink:String) {
    let fm = FileManager.default
    for i in 0 ..< links.count {
        let imagePath = localImagePath(links[i])
        let destDir = localDirectoryForPost(postLink)!
        let destImageName = destDir.vc_stringByAppendingPathComponent("\(i + 1)")
        if fm.fileExists(atPath: imagePath) && !fm.fileExists(atPath: destImageName) {
            do {
                try fm.copyItem(atPath: imagePath, toPath: destImageName)
            } catch _ {

            }
        }
    }
}

func imagesCached(forPostLink link:String) -> Bool {
    if let targetDir = localDirectoryForPost(link, create: false) {
        let fm = FileManager.default
        let numberOfFiles = (try! fm.contentsOfDirectory(atPath: targetDir)).count
        return numberOfFiles > 0 ? true : false
    }
    else {
        return false
    }
}

func siteLinks(_ forumID:Int) -> [String] {
    return baseLink(forumID).components(separatedBy: ";")
}

func getDaguerreLink(_ forumID:Int) -> String {
    if forumID == DaguerreForumID {
        let link = getValue(CurrentCLLinkKey) as? String
        if let l = link?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
            let clearedLink = l.replacingOccurrences(of: "(科学上网)", with: "", options: NSString.CompareOptions.caseInsensitive, range: l.range(of: l))
            return clearedLink
        }
        else {
            let links = siteLinks(DaguerreForumID)
            var l = links[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            l = l.replacingOccurrences(of: "(科学上网)", with: "", options: NSString.CompareOptions.caseInsensitive, range: l.range(of: l))
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

func mainThemeColor() -> UIColor {
    return #colorLiteral(red: 0.9259296656, green: 0.5184776783, blue: 0.6779794693, alpha: 1)
}

extension Data {
    func stringFromGB18030Data() -> String? {
        // CP 936: GBK, CP 54936: GB18030
        //let cfEncoding = CFStringConvertWindowsCodepageToEncoding(54936) //GB18030
        let cfgb18030encoding = CFStringEncodings.GB_18030_2000.rawValue
        let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfgb18030encoding))
        return String(data: self, encoding: String.Encoding(rawValue: gbkEncoding))
    }
}

// If the string is not a valid url, return component.
extension String {
    func vc_stringByAppendingPathComponent(_ component : String) -> String {
        guard let url = URL(string: self) else {
            return component
        }
        return url.appendingPathComponent(component).absoluteString
    }

    // More generic encoding replacement
    func htmlEncodingCleanup() -> String {
        let encodings = ["gbk", "GBK", "gb2312", "GB2312", "gb18030", "GB18030"]
        var s = self
        for enc in encodings {
            if !s.contains(enc) { continue }
            s = s.replacingOccurrences(of: enc, with: "utf-8")
        }
        return s
    }
}

// Statusbar color navigationcontroller
extension UINavigationController {
    override open var preferredStatusBarStyle : UIStatusBarStyle {
        if presentingViewController != nil {
            return presentingViewController!.preferredStatusBarStyle
        }
        else {
            guard topViewController != nil else { return .default }
            return (topViewController!.preferredStatusBarStyle);
        }
    }
}
