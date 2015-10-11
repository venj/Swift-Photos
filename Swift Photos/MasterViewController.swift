//
//  MasterViewController.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import Alamofire
import MMAppSwitcher
import MWPhotoBrowser
import PKHUD
import InAppSettingsKit
import SDWebImage
import PasscodeLock
import FlatUIColors

class MasterViewController: UITableViewController, UIActionSheetDelegate, IASKSettingsDelegate, MWPhotoBrowserDelegate, UISearchControllerDelegate {
    
    var posts:[Post] = [Post]()
    var filteredPosts:[Post] = [Post]()
    var images:[String] = [String]()
    var page = 1
    var forumID = DaguerreForumID
    var daguerreLink:String = ""
    var currentTitle:String = ""
    var currentCLLink:String = ""
    var settingsViewController:IASKAppSettingsViewController!
    var sheet:UIActionSheet!
    var searchController:UISearchController!
    var resultsController:SearchResultController!
    var myActivity : NSUserActivity!
    private var settingsController : UIViewController?

    let categories = [localizedString("Daguerre's Flag", comment: "達蓋爾的旗幟"): 16,
                      localizedString("Young Beauty", comment: "唯美贴图"): 53,
                      localizedString("Sexy Beauty", comment: "激情贴图"): 70,
                      localizedString("Cam Shot", comment: "走光偷拍"): 81,
                      localizedString("Selfies", comment: "网友自拍"): 59,
                      localizedString("Hentai Manga", comment: "动漫漫画"): 46,
                      localizedString("Celebrities", comment: "明星八卦"): 79,
                      localizedString("Alternatives", comment: "另类贴图"): 60]

    // MARK: - ViewController life cycle
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let savedTitle: String? = getValue(LastViewedSectionTitle) as? String
        if let t: String = savedTitle {
            categories[t] != nil ? title = savedTitle : setDefaultTitle()
        }
        else {
            setDefaultTitle()
        }
        let categoryButton = UIBarButtonItem(title: localizedString("Categories", comment: "分类"), style: .Plain, target: self, action: "showSections:")
        let settingsButton = UIBarButtonItem(title: localizedString("Settings", comment: "设置"), style: .Plain, target: self, action: "showSettings:")
        navigationItem.rightBarButtonItems = [settingsButton, categoryButton]
        loadFirstPageForKey(title!)
        
        tableView.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
        // SearchBar
        resultsController = SearchResultController()
        searchController = UISearchController(searchResultsController: resultsController)
        searchController.searchResultsUpdater = resultsController
        let searchBar = searchController.searchBar
        self.tableView.tableHeaderView = searchBar
        searchBar.sizeToFit()
        searchBar.placeholder = localizedString("Search loaded posts", comment: "搜索已加载的帖子")

        if #available(iOS 9, *) {
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func parseDaguerreLink() {
        let link = getDaguerreLink(self.forumID)
        let hud = PKHUD.sharedHUD
        hud.contentView = PKHUDTextView(text: localizedString("Parsing Daguerre Link...", comment: "HUD for parsing Daguerre's Flag link."))
        hud.show()
        let request = Alamofire.request(.GET, link + "index.php")
        request.responseData { [unowned self] response in
            if response.result.isSuccess {
                guard let str = response.data?.stringFromGB18030Data() else { return }
                let regexString = "<a href=\"([^\"]+)\">達蓋爾的旗幟</a>"
                do {
                    let regex = try NSRegularExpression(pattern: regexString, options: .CaseInsensitive)
                    let matches = regex.matchesInString(str, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, str.characters.count))
                    if matches.count > 0 {
                        let match = matches[0]
                        self.daguerreLink = link + str.substringWithRange(str.rangeFromNSRange(match.rangeAtIndex(1))!)
                    }
                }
                catch let error {
                    print(error)
                }
                hud.hide()
                self.loadPostList(self.daguerreLink, forPage: 1)
            }
            else {
                hud.hide()
                let alert = UIAlertController(title: localizedString("Network error", comment: "Network error happened, typically timeout."), message: localizedString("Failed to reach 1024 in time. Maybe links are dead. You may use a VPN to access 1024.", comment: "1024 link down."), preferredStyle: .Alert)
                let action = UIAlertAction(title: "OK", style: .Default, handler: { _ in
                    dispatch_async(dispatch_get_main_queue(), {
                        hud.contentView = PKHUDTextView(text: localizedString("1024 down, use a mirror", comment: ""))
                        hud.hide(afterDelay: 2.0)
                    })
                })
                alert.addAction(action)
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    func loadPostList(link:String, forPage page:Int) {
        if myActivity != nil {
            myActivity.invalidate()
        }
        if link != "" {
            myActivity = NSUserActivity(activityType: "me.venj.Swift-Photos.Continuity")
            myActivity.webpageURL = NSURL(string: link)
            myActivity.becomeCurrent()
        }

        let hud = showHUD()
        let l = link + "&page=\(self.page)"
        let request = Alamofire.request(.GET, l)
        request.responseData { [unowned self] response in
            if (response.result.isSuccess) {
                guard let str = response.data?.stringFromGB18030Data() else { return }
                var regexString:String
                var linkIndex = 0, titleIndex = 0
                if self.forumID == DaguerreForumID {
                    regexString = "[^\\d\\s]\\s+<h3><a href=\"(htm_data[^\"]+?)\"[^>]+?>(<font [^>]+?>)?(.+?(\\[\\d+[^\\[]+?\\])?)(</font>)?</a></h3>"
                    linkIndex = 1
                    titleIndex = 3
                }
                else {
                    regexString = "<a href=\"(viewthread\\.php[^\"]+?)\">([^\\d<]+?\\d+[^\\d]+?)</a>"
                    linkIndex = 1
                    titleIndex = 2
                }
                do {
                    let regex = try NSRegularExpression(pattern: regexString, options: .CaseInsensitive)
                    let matches = regex.matchesInString(str, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, str.characters.count))
                    var indexPathes:[NSIndexPath] = [NSIndexPath]()
                    let cellCount = self.posts.count
                    for var i = 0; i < matches.count; ++i {
                        let match: AnyObject = matches[i]
                        let link = getDaguerreLink(self.forumID) + str.substringWithRange(str.rangeFromNSRange(match.rangeAtIndex(linkIndex))!)
                        let title = str.substringWithRange(str.rangeFromNSRange(match.rangeAtIndex(titleIndex))!)
                        self.posts.append(Post(title: title, link: link))
                        indexPathes.append(NSIndexPath(forRow:cellCount + i, inSection: 0))
                        self.resultsController.posts = self.posts // Assignment
                    }
                    hud.hide()
                    self.tableView.insertRowsAtIndexPaths(indexPathes, withRowAnimation:.Top)
                    self.page++
                }
                catch let error {
                    print(error)
                }
            }
            else {
                hud.hide()
                dispatch_async(dispatch_get_main_queue(), {
                    hud.contentView = PKHUDTextView(text: localizedString("Request timeout.", comment: "Request timeout hud."))
                    hud.hide(afterDelay: 1.0)
                })
            }
        }
    }
    
    func loadPostListForPage(page:Int) {
        var link:String
        if forumID == DaguerreForumID {
            if daguerreLink == "" {
                self.parseDaguerreLink()
            }
            else {
                loadPostList(daguerreLink, forPage: page)
            }
        }
        else {
            link = baseLink(forumID) + "forumdisplay.php?fid=\(forumID)"
            loadPostList(link, forPage: page)
        }
    }
    
    // MARK: - Table View
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! ProgressTableViewCell

        cell.textLabel?.text = posts[indexPath.row].title
        cell.textLabel?.backgroundColor = UIColor.clearColor()
        let post = posts[indexPath.row]
        let link = post.link
        if imagesCached(forPostLink: link) {
            cell.textLabel?.textColor = FlatUIColors.belizeHoleColor()
        }
        else {
            cell.textLabel?.textColor = UIColor.blackColor()
        }
        cell.progress = post.progress
        cell.indentationWidth = -15.0
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let link = posts[indexPath.row].link
        self.images = [String]()
        // Local Data
        if imagesCached(forPostLink: link) {
            let localDir = localDirectoryForPost(link, create: false)
            let basePath = NSURL(fileURLWithPath: localDir!).absoluteString
            let fm = NSFileManager.defaultManager()
            var images : [String] = [String]()
            let files = try! fm.contentsOfDirectoryAtPath(localDir!)
            for f in files {
                images.append(basePath.vc_stringByAppendingPathComponent(f as String))
            }
            self.images = images
            let photoBrowser = MWPhotoBrowser(delegate: self)
            self.currentTitle = tableView.cellForRowAtIndexPath(indexPath)!.textLabel!.text!
            photoBrowser.displayActionButton = true
            photoBrowser.zoomPhotosToFill = false
            photoBrowser.displayNavArrows = true
            self.navigationController?.pushViewController(photoBrowser, animated: true)
        }
        else {
            //remote data
            let hud = showHUD()
            fetchImageLinks(fromPostLink: link, completionHandler: { [unowned self] fetchedImages in
                hud.hide()
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                // Skip non pics
                if fetchedImages.count == 0 {
                    return
                }
                // prefetch images
                self.fetchImagesToCache(fetchedImages, withProgressAction: { (progress) in })
                self.images = fetchedImages
                let aCell:UITableViewCell = tableView.cellForRowAtIndexPath(indexPath)!
                self.currentTitle = aCell.textLabel!.text!
                let photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser.displayActionButton = true
                photoBrowser.zoomPhotosToFill = false
                photoBrowser.displayNavArrows = true
                self.navigationController?.pushViewController(photoBrowser, animated: true)
                if self.myActivity != nil {
                    self.myActivity.invalidate()
                }
                self.myActivity = NSUserActivity(activityType: "me.venj.Swift-Photos.Continuity")
                self.myActivity.webpageURL = NSURL(string: link)
                self.myActivity.becomeCurrent()
            },
            errorHandler: {
                hud.hide()
                dispatch_async(dispatch_get_main_queue(), {
                    hud.contentView = PKHUDTextView(text:localizedString("Request timeout.", comment: "Request timeout hud."))
                    hud.hide(afterDelay: 1.0)
                })
            })
        }
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == posts.count - 1 {
            loadPostListForPage(page)
        }
        
        // Seperator inset fix from Stack Overflow: http://stackoverflow.com/questions/25770119/ios-8-uitableview-separator-inset-0-not-working
        // iOS 8 and up
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsetsZero
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if (indexPath.row < 0) { return nil }
        let preloadAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: localizedString("Preload", comment: "Preload Button.")) { (action, indexPath) in
            self.cacheImages(forIndexPath: indexPath, withProgressAction: { [unowned self] (progress) in
                // Update Progress.
                // FIXME: If the cell is preloading, and we switch to another section, the progress will keep updating.
                guard let cell = tableView.cellForRowAtIndexPath(indexPath) as? ProgressTableViewCell else { return }
                self.posts[indexPath.row].progress = progress
                dispatch_async(dispatch_get_main_queue(), {
                    cell.progress = progress
                })
            })
            if tableView.editing {
                tableView.setEditing(false, animated: true)
            }
        }
        preloadAction.backgroundColor = FlatUIColors.wisteriaColor()
        //Save
        let link = posts[indexPath.row].link
        let saveAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: localizedString("Save", comment: "Save Button.")) { [unowned self] (_, indexPath) in
            let cell = tableView.cellForRowAtIndexPath(indexPath)!
            let spinWheel = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
            cell.accessoryView = spinWheel
            spinWheel.startAnimating()
            
            self.fetchImageLinks(fromPostLink: link, completionHandler: { [unowned self] fetchedImages in
                saveCachedLinksToHomeDirectory(fetchedImages, forPostLink: link)
                self.tableView.reloadData()
                spinWheel.stopAnimating()
                cell.accessoryView = nil
            }, errorHandler: {
                spinWheel.stopAnimating()
                cell.accessoryView = nil
            })
            
            if tableView.editing {
                tableView.setEditing(false, animated: true)
            }
        }
        saveAction.backgroundColor = UIColor.orangeColor()
        return [preloadAction, saveAction]
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if imagesCached(forPostLink: posts[indexPath.row].link) { return false }
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) { }
    
    // MARK: MWPhotoBrowser Delegate
    func numberOfPhotosInPhotoBrowser(photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(images.count)
    }
    
    func photoBrowser(photoBrowser: MWPhotoBrowser!, photoAtIndex index: UInt) -> MWPhotoProtocol! {
        let p = MWPhoto(URL: NSURL(string: images[Int(index)]))
        p.caption = "\(index + 1)/\(images.count)"
        return p
    }
    
    func photoBrowser(photoBrowser: MWPhotoBrowser!, titleForPhotoAtIndex index: UInt) -> String! {
        let t:NSMutableString = self.currentTitle.mutableCopy() as! NSMutableString
        let range = t.rangeOfString("[", options:.BackwardsSearch)
        if range.location != NSNotFound {
            t.insertString("\(index + 1)/", atIndex: range.location + 1)
            return t as String
        }
        return self.currentTitle
    }
    
    // MARK: Actions
    @IBAction func showSections(sender:AnyObject?) {
        if sheet == nil {
            let cancelTitle = localizedString("Cancel", comment: "Cancel button. (General)")
            sheet = UIActionSheet(title: localizedString("Please select a category", comment: "ActionSheet title."), delegate: self, cancelButtonTitle: cancelTitle, destructiveButtonTitle: nil)
            for key in categories.keys {
                sheet.addButtonWithTitle(key)
            }
        }
        if !sheet.visible {
            sheet.showFromBarButtonItem(navigationItem.rightBarButtonItems![1] , animated: true)
        }
    }
    
    @IBAction func showSettings(sender:AnyObject?) {
        if getValue(CurrentCLLinkKey) == nil {
            getDaguerreLink(self.forumID)
        }

        let hud = showHUD()
        SDImageCache.sharedImageCache().calculateSizeWithCompletionBlock() { [unowned self] (fileCount:UInt, totalSize:UInt) in
            let humanReadableSize = NSString(format: "%.1f MB", Double(totalSize) / (1024 * 1024))
            saveValue(humanReadableSize, forKey: ImageCacheSizeKey)

            let passcodeRepo = UserDefaultsPasscodeRepository()
            let status = passcodeRepo.hasPasscode ? localizedString("On", comment: "打开") : localizedString("Off", comment: "关闭")
            saveValue(status, forKey: PasscodeLockStatus)
            
            self.settingsViewController = IASKAppSettingsViewController(style: .Grouped)
            self.settingsViewController.delegate = self
            self.settingsViewController.showCreditsFooter = false
            let settingsNavigationController = UINavigationController(rootViewController: self.settingsViewController)
            settingsNavigationController.modalPresentationStyle = .FormSheet
            self.presentViewController(settingsNavigationController, animated: true) {}
            hud.hide()
        }
    }

    @IBAction func refresh(sender:AnyObject?) {
        let key = title
        currentCLLink = getDaguerreLink(self.forumID)
        let range = daguerreLink.rangeOfString(currentCLLink)
        if self.forumID == DaguerreForumID && range == nil {
            parseDaguerreLink()
        }
        else {
            loadFirstPageForKey(key!)
        }
    }
    
    // MARK: Helper
    func loadFirstPageForKey(key:String) {
        if tableView.editing {
            tableView.setEditing(false, animated: false)
        }
        forumID = categories[key]!
        posts = [Post]()
        page = 1
        tableView.reloadData()
        loadPostListForPage(page)
    }
    
    func recalculateCacheSize() {
        let size = SDImageCache.sharedImageCache().getSize()
        let humanReadableSize = NSString(format: "%.1f MB", Double(size) / (1024 * 1024))
        saveValue(humanReadableSize, forKey: ImageCacheSizeKey)
    }
    
    func fetchImageLinks(fromPostLink postLink:String, completionHandler:(([String]) -> Void)?, errorHandler:(() -> Void)?) {
        let request = Alamofire.request(.GET, postLink)
        request.responseData { [unowned self] response in
            var fetchedImages = [String]()
            if response.result.isSuccess {
                guard let str = response.data?.stringFromGB18030Data() else { errorHandler?() ; return }
                var regexString:String
                if self.forumID == DaguerreForumID {
                    regexString = "input.+?src=('|\")([^\"']+?)('|\")"
                }
                else {
                    regexString = "img src=\"([^\"]+)\" .+? onload"
                }
                do {
                    let regex = try NSRegularExpression(pattern: regexString, options: .CaseInsensitive)
                    let matches = regex.matchesInString(str, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, str.characters.count))
                    for match in matches {
                        var imageLink = str.substringWithRange(str.rangeFromNSRange(match.rangeAtIndex(self.forumID == DaguerreForumID ? 2 : 1))!)
                        imageLink = imageLink.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet)!
                        fetchedImages.append(imageLink)
                    }
                    completionHandler?(fetchedImages)
                }
                catch let error {
                    print(error)
                }
            }
            else {
                errorHandler?()
            }
        }
    }
    
    func setDefaultTitle() {
        title = localizedString("Young Beauty", comment: "唯美贴图")
    }
    
    // Don't care if the request is succeeded or not.
    func fetchImagesToCache(images:[String], withProgressAction progressAction:((Float) -> Void)? ) {
        var downloadedImagesCount = 0
        let totalImagesCount = images.count
        for image in images {
            if SDWebImageManager.sharedManager().cachedImageExistsForURL(NSURL(string: image)) {
                downloadedImagesCount++
                let progress = Float(downloadedImagesCount) / Float(totalImagesCount)
                progressAction?(progress)
                continue
            }
            let imageLink = image.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet)!
            Alamofire.download(.GET, imageLink, destination: { (_, _) in
                // 返回下载目标路径的 fileURL
                return NSURL.fileURLWithPath(localImagePath(image))
            }) // For Debug
            .progress { (_, totalBytesRead, totalBytesExpectedToRead) in
                if (totalBytesRead == totalBytesExpectedToRead) {
                    downloadedImagesCount += 1
                    let progress = Float(downloadedImagesCount) / Float(totalImagesCount)
                    progressAction?(progress)
                }
            } // For Debug
            .response { (_, response, _, _) in
                //print(response)
            }
        }
    }
    
    func cacheImages(forIndexPath indexPath: NSIndexPath, withProgressAction progressAction:(Float) -> Void) {
        let link = posts[indexPath.row].link
        fetchImageLinks(fromPostLink: link, completionHandler: { [unowned self] fetchedImages in
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
            // Skip non pics
            if fetchedImages.count == 0 {
                return
            }
            // prefetch images
            self.fetchImagesToCache(fetchedImages, withProgressAction:progressAction)
            },
            errorHandler: nil)
    }
    
    // MARK: ActionSheet Delegates
    func actionSheet(actionSheet: UIActionSheet, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex != actionSheet.cancelButtonIndex {
            let key = actionSheet.buttonTitleAtIndex(buttonIndex)
            title = key
            saveValue(key!, forKey: LastViewedSectionTitle)
            loadFirstPageForKey(key!)
        }
    }
    
    // MARK: Settings
    func settingsViewControllerDidEnd(sender: IASKAppSettingsViewController!) {
        sender.dismissViewControllerAnimated(true) {}
    }
    
    func settingsViewController(sender: IASKAppSettingsViewController!, buttonTappedForSpecifier specifier: IASKSpecifier!) {
        if specifier.key() == PasscodeLockConfig {
            let passcodeVC: PasscodeLockViewController
            let repository = UserDefaultsPasscodeRepository()
            let configuration = PasscodeLockConfiguration(repository: repository)
            if !repository.hasPasscode {
                passcodeVC = PasscodeLockViewController(state: .SetPasscode, configuration: configuration)
                passcodeVC.successCallback = { lock in
                    let status = localizedString("On", comment: "打开")
                    saveValue(status, forKey: PasscodeLockStatus)
                }
            }
            else {
                passcodeVC = PasscodeLockViewController(state: .RemovePasscode, configuration: configuration)
                passcodeVC.successCallback = { lock in
                    lock.repository.deletePasscode()
                    let status = localizedString("Off", comment: "关闭")
                    saveValue(status, forKey: PasscodeLockStatus)
                }
            }
            passcodeVC.dismissCompletionCallback = {
                sender.tableView.reloadData()
            }
            sender.navigationController?.pushViewController(passcodeVC, animated: true)
        }
        else if specifier.key() == ClearCacheNowKey {
            let hud = showHUD()
            SDImageCache.sharedImageCache().clearDiskOnCompletion() { [unowned self] in
                self.recalculateCacheSize()
                dispatch_async(dispatch_get_main_queue(), {
                    hud.contentView = PKHUDTextView(text: localizedString("Cache Cleared", comment: "缓存已清除"))
                    hud.hide(afterDelay: 1.0)
                    sender.tableView.reloadData()
                })
            }
        }
        else if specifier.key() == ClearDownloadCacheKey {
            let hud = showHUD()
            clearDownloadCache() {
                dispatch_async(dispatch_get_main_queue(), {
                    hud.contentView = PKHUDTextView(text: localizedString("Cache Cleared", comment: "缓存已清除"))
                    hud.hide(afterDelay: 1.0)
                    sender.tableView.reloadData()
                })
            }
        }
        else if specifier.key() == CurrentCLLinkKey {
            // Load links from web.
            settingsController = sender
            fetchCLLinks({ (links) -> () in
                let linksController = CLLinksTableViewTableViewController(style:.Grouped);
                guard let l = links else { return }
                if l.count == 0 {
                    linksController.clLinks = siteLinks(DaguerreForumID)
                }
                else {
                    linksController.clLinks = l
                }

                sender.navigationController?.pushViewController(linksController, animated: true)
            })

        }
    }

    func fetchCLLinks( complete: (links : [String]?)->() ) {
        let hud = showHUD()
        let textLink = "ht" + "tp" + "://" + "ww" + "w" + ".su" + "ki" + "ap" + "p" + "s.co" + "m/c" + "l.t" + "xt"
        let request = Alamofire.request(.GET, textLink)
        request.responseString { (response) in
            if response.result.isSuccess {
                hud.hide()
                let str = response.result.value
                let links = str?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).componentsSeparatedByString(";")
                complete(links: links)
            }
            else {
                hud.hide()
                dispatch_async(dispatch_get_main_queue(), {
                    hud.contentView = PKHUDTextView(text:localizedString("Request timeout.", comment: "Request timeout hud."))
                    hud.hide(afterDelay: 1.0)
                    complete(links: [String]())
                })
            }
        }
    }

    func clearDownloadCache( complete: ()->() ) {
        let tempDir = NSTemporaryDirectory();
        //println(tempDir)
        let fm = NSFileManager.defaultManager()
        if let contents = try? fm.contentsOfDirectoryAtPath(tempDir) {
            for item in contents {
                do {
                    try fm.removeItemAtPath(tempDir.vc_stringByAppendingPathComponent(item))
                } catch _ {
                }
            }
        }
        complete()
    }
    
    // MARK: UISearchResultUpdating
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        filteredPosts.removeAll(keepCapacity: true)
    }
    
    func didPresentSearchController(searchController: UISearchController) {
        resultsController.forumID = self.forumID
    }
}

