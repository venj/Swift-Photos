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
import MBProgressHUD
import InAppSettingsKit
import SDWebImage
import LTHPasscodeViewController

class MasterViewController: UITableViewController, UIActionSheetDelegate, IASKSettingsDelegate, MWPhotoBrowserDelegate, UISearchControllerDelegate {
    
    var posts:[Post] = []
    var filteredPosts:[Post] = []
    var images:[String] = []
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
    
    let categories = [NSLocalizedString("Daguerre's Flag", tableName: nil, value: "Daguerre's Flag", comment: "達蓋爾的旗幟"): 16,
                      NSLocalizedString("Young Beauty", tableName: nil, value: "Young Beauty", comment: "唯美贴图"): 53,
                      NSLocalizedString("Sexy Beauty", tableName: nil, value: "Sexy Beauty", comment: "激情贴图"): 70,
                      NSLocalizedString("Cam Shot", tableName: nil, value: "Cam Shot", comment: "走光偷拍"): 81,
                      NSLocalizedString("Selfies", tableName: nil, value: "Selfies", comment: "网友自拍"): 59,
                      NSLocalizedString("Hentai Manga", tableName: nil, value: "Hentai Manga", comment: "动漫漫画"): 46,
                      NSLocalizedString("Celebrities", tableName: nil, value: "Celebrities", comment: "明星八卦"): 79,
                      NSLocalizedString("Alternatives", tableName: nil, value: "Alternatives", comment: "另类贴图"): 60]
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        (UIApplication.sharedApplication().delegate as! AppDelegate).showPassLock()
        let savedTitle: AnyObject! = getValue(LastViewedSectionTitle)
        if let t: AnyObject = savedTitle {
            categories[(t as! String)] != nil ? title = (savedTitle as! String) : setDefaultTitle()
        }
        else {
            setDefaultTitle()
        }
        let categoryButton = UIBarButtonItem(title: NSLocalizedString("Categories", tableName: nil, value: "Categories", comment: "分类"), style: .Plain, target: self, action: "showSections:")
        let settingsButton = UIBarButtonItem(title: NSLocalizedString("Settings", tableName: nil, value: "Settings", comment: "设置"), style: .Plain, target: self, action: "showSettings:")
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
        searchBar.placeholder = NSLocalizedString("Search loaded posts", tableName: nil, value: "Search loaded posts", comment: "搜索已加载的帖子")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func parseDaguerreLink() {
        let link = getDaguerreLink(self.forumID)
        var hud = showHUDInView(self.navigationController!.view, withMessage: NSLocalizedString("Parsing Daguerre Link...", tableName: nil, value: "Parsing Daguerre Link...", comment: "HUD for parsing Daguerre's Flag link."), afterDelay: 0.0)
        let request = Alamofire.request(.GET, link + "index.php")
        request.response { [weak self] (request, response, data, error) in
            let strongSelf = self!
            if (error?.domain != nil) {
                hud.hide(true)
                let alert = UIAlertController(title: NSLocalizedString("Network error", tableName: nil, value: "Network error", comment: "Network error happened, typically timeout."), message: NSLocalizedString("Failed to reach 1024 in time. Maybe links are dead. You may use a VPN to access 1024.", tableName: nil, value: "Network error", comment: "1024 link down."), preferredStyle: .Alert)
                let action = UIAlertAction(title: "OK", style: .Default, handler: { [weak self] (action) -> Void in
                    showHUDInView(self!.navigationController!.view, withMessage: NSLocalizedString("1024 down, use a mirror", tableName: nil, value: "1024 down, use a mirror", comment: ""), afterDelay: 2.0)
                })
                alert.addAction(action)
                strongSelf.presentViewController(alert, animated: true, completion: nil)
                return
            }
            else {
                if data != nil {
                    var str:NSString = data!.stringFromGB18030Data()
                    var err:NSError?
                    let regexString:String = "<a href=\"([^\"]+?)\">達蓋爾的旗幟</a>"
                    var linkIndex = 0, titleIndex = 0
                    var regex = NSRegularExpression(pattern: regexString, options: .CaseInsensitive, error: &err)
                    let matches = regex?.matchesInString(str as String, options: nil, range: NSMakeRange(0, str.length))
                    if matches!.count > 0 {
                        let match: AnyObject = matches![0]
                        strongSelf.daguerreLink = link + str.substringWithRange(match.rangeAtIndex(1))
                    }

                }
                hud.hide(true)
            }
            strongSelf.loadPostList(strongSelf.daguerreLink, forPage: 1)
        }
    }
    
    func loadPostList(link:String, forPage page:Int) {
        if myActivity != nil {
            myActivity.invalidate()
        }
        myActivity = NSUserActivity(activityType: "me.venj.Swift-Photos.Continuity")
        myActivity.webpageURL = NSURL(string: link)
        myActivity.becomeCurrent()
        
        let hud = MBProgressHUD.showHUDAddedTo(navigationController?.view, animated: true)
        let request = Alamofire.request(.GET, link + "&page=\(self.page)")
        request.response { [weak self] (request, response, data, error) in
            let strongSelf = self!
            if error?.domain == nil {
                if data != nil {
                    var str:NSString = data!.stringFromGB18030Data()
                    var err:NSError?
                    var regexString:String
                    var linkIndex = 0, titleIndex = 0
                    if strongSelf.forumID == DaguerreForumID {
                        //regexString = "<a href=\"([^\"]+?)\"[^>]+?>(<font [^>]+?>)?([^\\d<]+?\\[\\d+[^\\d]+?)(</font>)?</a>"
                        regexString = "[^\\d\\s]\\s+<h3><a href=\"(htm_data[^\"]+?)\"[^>]+?>(<font [^>]+?>)?(.+?(\\[\\d+[^\\[]+?\\])?)(</font>)?</a></h3>"
                        linkIndex = 1
                        titleIndex = 3
                    }
                    else {
                        regexString = "<a href=\"(viewthread\\.php[^\"]+?)\">([^\\d<]+?\\d+[^\\d]+?)</a>"
                        linkIndex = 1
                        titleIndex = 2
                    }
                    var regex = NSRegularExpression(pattern: regexString, options: .CaseInsensitive, error: &err)
                    let matches = regex!.matchesInString(str as String, options: nil, range: NSMakeRange(0, str.length))
                    var indexPathes:Array<NSIndexPath> = []
                    var cellCount = strongSelf.posts.count
                    for var i = 0; i < matches.count; ++i {
                        let match: AnyObject = matches[i]
                        let link = getDaguerreLink(strongSelf.forumID) + str.substringWithRange(match.rangeAtIndex(linkIndex))
                        let title = str.substringWithRange(match.rangeAtIndex(titleIndex))
                        strongSelf.posts.append(Post(title: title, link: link))
                        indexPathes.append(NSIndexPath(forRow:cellCount + i, inSection: 0))
                        strongSelf.resultsController.posts = strongSelf.posts // Assignment
                    }
                    hud.hide(true)
                    strongSelf.tableView.insertRowsAtIndexPaths(indexPathes, withRowAnimation:.Top)
                    strongSelf.page++
                }
            }
            else {
                // Handle error
                hud.hide(true)
                showHUDInView(self!.navigationController!.view, withMessage: NSLocalizedString("Request timeout.", tableName: nil, value: "Request timeout.", comment: "Request timeout hud."), afterDelay: 1)
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
            link = baseLink(forumID) + "forumdisplay.php?fid=\(forumID)&page=\(page)"
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
            cell.textLabel?.textColor = UIColor.iOS8darkBlueColor()
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
        self.images = []
        // Local Data
        if imagesCached(forPostLink: link) {
            let localDir = localDirectoryForPost(link, create: false)
            let basePath = NSURL(fileURLWithPath: localDir!)?.absoluteString
            let fm = NSFileManager.defaultManager()
            var images : [String] = []
            let files = fm.contentsOfDirectoryAtPath(localDir!, error: nil)!
            for f in files {
                if let base = basePath {
                    images.append(base.stringByAppendingPathComponent(f as! String))
                }
            }
            self.images = images
            var photoBrowser = MWPhotoBrowser(delegate: self)
            self.currentTitle = tableView.cellForRowAtIndexPath(indexPath)!.textLabel!.text!
            photoBrowser.displayActionButton = true
            photoBrowser.zoomPhotosToFill = false
            photoBrowser.displayNavArrows = true
            self.navigationController?.pushViewController(photoBrowser, animated: true)
        }
        else {
            //remote data
            let hud = MBProgressHUD.showHUDAddedTo(navigationController?.view, animated: true)
            fetchImageLinks(fromPostLink: link, completionHandler: { [weak self] fetchedImages in
                let strongSelf = self!
                hud.hide(true)
                strongSelf.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                // Skip non pics
                if fetchedImages.count == 0 {
                    return
                }
                // prefetch images
                strongSelf.fetchImagesToCache(fetchedImages, withProgressAction: { (progress) -> Void in })
                strongSelf.images = fetchedImages
                let aCell:UITableViewCell = tableView.cellForRowAtIndexPath(indexPath)!
                strongSelf.currentTitle = aCell.textLabel!.text!
                var photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser.displayActionButton = true
                photoBrowser.zoomPhotosToFill = false
                photoBrowser.displayNavArrows = true
                strongSelf.navigationController?.pushViewController(photoBrowser, animated: true)
                if strongSelf.myActivity != nil {
                    strongSelf.myActivity.invalidate()
                }
                strongSelf.myActivity = NSUserActivity(activityType: "me.venj.Swift-Photos.Continuity")
                strongSelf.myActivity.webpageURL = NSURL(string: link)
                strongSelf.myActivity.becomeCurrent()
                },
                errorHandler: { [weak self] in
                    hud.hide(true)
                    showHUDInView(self!.navigationController!.view, withMessage: NSLocalizedString("Request timeout.", tableName: nil, value: "Request timeout.", comment: "Request timeout hud."), afterDelay: 1)
            })
        }
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == posts.count - 1 {
            loadPostListForPage(page)
        }
        
        // Seperator inset fix from Stack Overflow: http://stackoverflow.com/questions/25770119/ios-8-uitableview-separator-inset-0-not-working
        if cell.respondsToSelector("setSeparatorInset:") {
            cell.separatorInset = UIEdgeInsetsZero
        }
        if cell.respondsToSelector("setPreservesSuperviewLayoutMargins:") {
            cell.preservesSuperviewLayoutMargins = false
        }
        if cell.respondsToSelector("setLayoutMargins:") {
            cell.layoutMargins = UIEdgeInsetsZero
        }
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if (indexPath.row < 0) { return nil }
        let preloadAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: NSLocalizedString("Preload", tableName: nil, value: "Preload", comment: "Preload Button.")) { (action, indexPath) -> Void in
            self.cacheImages(forIndexPath: indexPath, withProgressAction: { [weak self] (progress) -> Void in
                // Update Progress.
                let cell = tableView.cellForRowAtIndexPath(indexPath) as? ProgressTableViewCell
                self?.posts[indexPath.row].progress = progress
                if let c = cell {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        c.progress = progress
                    })
                }
            })
            if tableView.editing {
                tableView.setEditing(false, animated: true)
            }
        }
        preloadAction.backgroundColor = UIColor.iOS8purpleColor()
        //Save
        let link = posts[indexPath.row].link
        let saveAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: NSLocalizedString("Save", tableName: nil, value: "Save", comment: "Save Button.")) { [weak self] (action, indexPath) -> Void in
            let cell = tableView.cellForRowAtIndexPath(indexPath)!
            let spinWheel = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
            cell.accessoryView = spinWheel
            spinWheel.startAnimating()
            
            self?.fetchImageLinks(fromPostLink: link, completionHandler: { [weak self] fetchedImages in
                let strongSelf = self!
                saveCachedLinksToHomeDirectory(fetchedImages, forPostLink: link)
                strongSelf.tableView.reloadData()
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
        saveAction.backgroundColor = UIColor.iOS8orangeColor()
        return [preloadAction, saveAction]
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        //if indexPath.row < 0 { return false }
        if imagesCached(forPostLink: posts[indexPath.row].link) { return false }
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) { }
    
    // MARK: MWPhotoBrowser Delegate
    func numberOfPhotosInPhotoBrowser(photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(images.count)
    }
    
    func photoBrowser(photoBrowser: MWPhotoBrowser!, photoAtIndex index: UInt) -> MWPhotoProtocol! {
        var p = MWPhoto(URL: NSURL(string: images[Int(index)]))
        p.caption = "\(index + 1)/\(images.count)"
        return p
    }
    
    func photoBrowser(photoBrowser: MWPhotoBrowser!, titleForPhotoAtIndex index: UInt) -> String! {
        var t:NSMutableString = self.currentTitle.mutableCopy() as! NSMutableString
        let range = t.rangeOfString("[", options:.BackwardsSearch)
        // FIXME: Why can't I use NSNotFound here
        if range.location != NSIntegerMax {
            t.insertString("\(index + 1)/", atIndex: range.location + 1)
            return t as String
        }
        return self.currentTitle
    }
    
    // MARK: Actions
    @IBAction func showSections(sender:AnyObject?) {
        if sheet == nil {
            let majorVersion = systemMajorVersion()
            let cancelTitle = NSLocalizedString("Cancel", tableName: nil, value: "Cancel", comment: "Cancel button. (General)")
            sheet = UIActionSheet(title: NSLocalizedString("Please select a category", tableName: nil, value: "Please select a category", comment: "ActionSheet title."), delegate: self, cancelButtonTitle: majorVersion != 7 ? cancelTitle : nil, destructiveButtonTitle: nil)
            for key in categories.keys {
                sheet.addButtonWithTitle(key)
            }
            if majorVersion == 7 && userInterfaceIdiom() == .Phone {
                sheet.addButtonWithTitle(cancelTitle)
            }
        }
        if !sheet.visible {
            sheet.showFromBarButtonItem(navigationItem.rightBarButtonItems![1] as! UIBarButtonItem, animated: true)
        }
    }
    
    @IBAction func showSettings(sender:AnyObject?) {
        if getValue(CurrentCLLinkKey) == nil {
            getDaguerreLink(self.forumID)
        }
        
        let settingsHUD = MBProgressHUD.showHUDAddedTo(navigationController?.view, animated: true)
        SDImageCache.sharedImageCache().calculateSizeWithCompletionBlock() { [weak self] (fileCount:UInt, totalSize:UInt) in
            let strongSelf = self!
            let humanReadableSize = NSString(format: "%.1f MB", Double(totalSize) / (1024 * 1024))
            saveValue(humanReadableSize, forKey: ImageCacheSizeKey)
            
            let status = LTHPasscodeViewController.doesPasscodeExist() ? localizedString("On", "打开") : localizedString("Off", "关闭")
            saveValue(status, forKey: PasscodeLockStatus)
            
            strongSelf.settingsViewController = IASKAppSettingsViewController(style: .Grouped)
            strongSelf.settingsViewController.delegate = self
            strongSelf.settingsViewController.showCreditsFooter = false
            let settingsNavigationController = UINavigationController(rootViewController: strongSelf.settingsViewController)
            settingsNavigationController.modalPresentationStyle = .FormSheet
            strongSelf.presentViewController(settingsNavigationController, animated: true) {}
            settingsHUD.hide(true)
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
        posts = []
        page = 1
        tableView.reloadData()
        loadPostListForPage(page)
    }
    
    func recalculateCacheSize() {
        let size = SDImageCache.sharedImageCache().getSize()
        let humanReadableSize = NSString(format: "%.1f MB", Double(size) / (1024 * 1024))
        saveValue(humanReadableSize, forKey: ImageCacheSizeKey)
    }
    
    func fetchImageLinks(fromPostLink postLink:String, completionHandler:((Array<String>) -> Void), errorHandler:(() -> Void)) {
        let request = Alamofire.request(.GET, postLink)
        request.response { [weak self] (request, response, data, error) in
            let strongSelf = self!
            var fetchedImages = Array<String>()
            if error?.domain == nil {
                if data != nil {
                    var str:NSString = data!.stringFromGB18030Data()
                    var error:NSError?
                    var regexString:String
                    if strongSelf.forumID == DaguerreForumID {
                        regexString = "input type='image' src='([^\"]+?)'"
                    }
                    else {
                        regexString = "img src=\"([^\"]+)\" .+? onload"
                    }
                    var regex = NSRegularExpression(pattern: regexString, options: .CaseInsensitive, error: &error)
                    let matches = regex!.matchesInString(str as String, options: nil, range: NSMakeRange(0, str.length))
                    for match in matches {
                        var imageLink = str.substringWithRange(match.rangeAtIndex(1))
                        imageLink = imageLink.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
                        fetchedImages.append(imageLink)
                        //println("\(imageLink)")
                    }
                    completionHandler(fetchedImages)
                }
            }
            else {
                // Handle error
                errorHandler()
            }
        }
    }
    
    func setDefaultTitle() {
        title = NSLocalizedString("Young Beauty", tableName: nil, value: "Young Beauty", comment: "唯美贴图")
    }
    
    // Don't care if the request is succeeded or not.
    func fetchImagesToCache(images:[String], withProgressAction progressAction:(Float) -> Void ) {
        var image = ""
        let path = ""
        var downloadedImagesCount = 0
        let totalImagesCount = images.count
        for image in images {
            if SDWebImageManager.sharedManager().cachedImageExistsForURL(NSURL(string: image)) {
                downloadedImagesCount++
                let progress = Float(downloadedImagesCount) / Float(totalImagesCount)
                progressAction(progress)
                continue
            }
            let imageLink = image.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
            Alamofire.download(.GET, imageLink, destination: { (temporaryURL, response) in
                // 返回下载目标路径的 fileURL
                let imageURL = NSURL.fileURLWithPath(localImagePath(image))
                if let directory = imageURL {
                    return directory
                }
                return temporaryURL
            }) // For Debug
            .progress { (bytesRead, totalBytesRead, totalBytesExpectedToRead) in
                if (totalBytesRead == totalBytesExpectedToRead) {
                    downloadedImagesCount += 1
                    let progress = Float(downloadedImagesCount) / Float(totalImagesCount)
                    progressAction(progress)
                }
            } // For Debug
            .response { (request, response, _, error) in
                //println(response)
            }
        }
    }
    
    func cacheImages(forIndexPath indexPath: NSIndexPath, withProgressAction progressAction:(Float) -> Void) {
        let link = posts[indexPath.row].link
        fetchImageLinks(fromPostLink: link, completionHandler: { [weak self] fetchedImages in
            let strongSelf = self!
            strongSelf.tableView.deselectRowAtIndexPath(indexPath, animated: true)
            // Skip non pics
            if fetchedImages.count == 0 {
                return
            }
            // prefetch images
            strongSelf.fetchImagesToCache(fetchedImages, withProgressAction:progressAction)
            },
            errorHandler: { [weak self] in
            })
    }
    
    // MARK: ActionSheet Delegates
    func actionSheet(actionSheet: UIActionSheet, didDismissWithButtonIndex buttonIndex: Int) {
        if systemMajorVersion() == 7 && buttonIndex == (actionSheet.numberOfButtons - 1) && userInterfaceIdiom() == .Phone {
            return
        }
        if buttonIndex != actionSheet.cancelButtonIndex {
            let key = actionSheet.buttonTitleAtIndex(buttonIndex)
            title = key
            saveValue(key, forKey: LastViewedSectionTitle)
            loadFirstPageForKey(key)
        }
    }
    
    // MARK: Settings
    func settingsViewControllerDidEnd(sender: IASKAppSettingsViewController!) {
        sender.dismissViewControllerAnimated(true) {}
    }
    
    func settingsViewController(sender: IASKAppSettingsViewController!, buttonTappedForSpecifier specifier: IASKSpecifier!) {
        if specifier.key() == PasscodeLockConfig {
            if !LTHPasscodeViewController.doesPasscodeExist() {
                LTHPasscodeViewController.sharedUser().showForEnablingPasscodeInViewController(sender, asModal: false)
            }
            else {
                LTHPasscodeViewController.sharedUser().showForDisablingPasscodeInViewController(sender, asModal: false)
            }
        }
        else if specifier.key() == ClearCacheNowKey {
            let aView = sender.navigationController?.view
            let hud = MBProgressHUD.showHUDAddedTo(aView, animated: true)
            SDImageCache.sharedImageCache().clearDiskOnCompletion() { [weak self] in
                let strongSelf = self!
                hud.hide(true)
                strongSelf.recalculateCacheSize()
                showHUDInView(aView!, withMessage: localizedString("Cache Cleared", "缓存已清除"), afterDelay: 1.0)
                sender.tableView.reloadData()
            }
        }
        else if specifier.key() == ClearDownloadCacheKey {
            let aView = sender.navigationController?.view
            let hud = MBProgressHUD.showHUDAddedTo(aView, animated: true)
            clearDownloadCache() { [weak self] in
                let strongSelf = self!
                hud.hide(true)
                showHUDInView(aView!, withMessage: localizedString("Cache Cleared", "缓存已清除"), afterDelay: 1.0)
                sender.tableView.reloadData()
            }
        }
        else if specifier.key() == CurrentCLLinkKey {
            let linksController = CLLinksTableViewTableViewController(style:.Grouped);
            sender.navigationController?.pushViewController(linksController, animated: true)
        }
    }
    
    func clearDownloadCache( complete: ()->() ) {
        let tempDir = NSTemporaryDirectory();
        //println(tempDir)
        let fm = NSFileManager.defaultManager()
        if let contents = fm.contentsOfDirectoryAtPath(tempDir, error: nil) {
            for item in contents {
                fm.removeItemAtPath(tempDir.stringByAppendingPathComponent(item as! String), error: nil)
            }
        }
        complete()
    }
    
    // MARK: UISearchResultUpdating
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let searchString = searchController.searchBar.text
        filteredPosts.removeAll(keepCapacity: true)
    }
    
    func didPresentSearchController(searchController: UISearchController) {
        resultsController.forumID = self.forumID
    }
}

