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
import Fuzi

class MasterViewController: UITableViewController, IASKSettingsDelegate, MWPhotoBrowserDelegate, UISearchControllerDelegate, UIPopoverPresentationControllerDelegate {
    
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

        navigationController?.navigationBar.barTintColor = UIColor(rgba: "#E56C9D")
        navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.whiteColor()]


        //navigationItem.

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
                let xpath: String = "//h2/a"
                do {
                    let document = try HTMLDocument(string: str.htmlEncodingCleanup())
                    for element in document.xpath(xpath) {
                        guard let path = element["href"] else { continue }
                        if element.stringValue == "達蓋爾的旗幟" {
                            self.daguerreLink = link + path
                            break
                        }
                    }
                }
                catch _ {}
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
                let xpath: String = ( (self.forumID == DaguerreForumID) ? "//tr" : "//a" )
                do {
                    let document = try HTMLDocument(string: str.htmlEncodingCleanup())
                    let elements = document.xpath(xpath)
                    var indexPathes:[NSIndexPath] = [NSIndexPath]()
                    let cellCount = self.posts.count
                    var i = 0
                    for e in elements {
                        var element = e
                        if self.forumID == DaguerreForumID {
                            if e.stringValue.containsString("↑") { continue }
                            guard let elem = e.css("td h3 a").first else { continue }
                            element = elem
                        }
                        guard let link = element["href"] else { continue }
                        let filterString = ( (self.forumID == DaguerreForumID) ? "htm_data" : "viewthread.php" )
                        guard let _ = link.rangeOfString(filterString) else { continue }
                        let title = element.stringValue
                        //FIXME: 4 is much based on experience
                        if title.characters.count < 4 { continue }
                        self.posts.append(Post(title: title, link: getDaguerreLink(self.forumID) + link))
                        // Note the i++ here. It is much of a hack just for save one line.
                        indexPathes.append(NSIndexPath(forRow:cellCount + (i++), inSection: 0))
                    }
                    self.resultsController.posts = self.posts // Assignment
                    self.tableView.insertRowsAtIndexPaths(indexPathes, withRowAnimation:.Top)
                    self.page++
                    hud.hide()
                }
                catch _ {
                    hud.hide() // If any exception, hide the hud
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
        if post.imageCached {
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
        let sectionsController = UIAlertController(title: localizedString("Please select a category", comment: "ActionSheet title."), message: "", preferredStyle: .ActionSheet)
        sectionsController.popoverPresentationController?.delegate = self

        for key in categories.keys {
            let act = UIAlertAction(title: key, style: .Default, handler: { [unowned self] _ in
                saveValue(key, forKey: LastViewedSectionTitle)
                self.title = key
                self.loadFirstPageForKey(key)
            })
            sectionsController.addAction(act)
        }
        let cancelAction = UIAlertAction(title: localizedString("Cancel", comment: "Cancel button. (General)"), style: .Cancel, handler: nil)
        sectionsController.addAction(cancelAction)
        self.presentViewController(sectionsController, animated: true) {
            sectionsController.popoverPresentationController?.passthroughViews = nil
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

    // MARK: - UIPopoverPresentationControllerDelegate
    func prepareForPopoverPresentation(popoverPresentationController: UIPopoverPresentationController) {
        popoverPresentationController.barButtonItem = navigationItem.rightBarButtonItems?[1]
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
    
    func fetchImageLinks(fromPostLink postLink:String, async: Bool = true, completionHandler:(([String]) -> Void)? = nil, errorHandler:(() -> Void)? = nil) {
        var fetchedImages = [String]()
        if !async {
            guard let url = NSURL(string: postLink) else { return }
            let request = NSURLRequest(URL: url, cachePolicy: .ReloadIgnoringLocalCacheData, timeoutInterval: requestTimeOutForWeb)
            do {
                let data = try NSURLConnection.sendSynchronousRequest(request, returningResponse:nil)
                guard let str = data.stringFromGB18030Data() else { return }
                fetchedImages = readImageLinks(str)
                completionHandler?(fetchedImages)
            }
            catch _ {}
        }
        else {
            let request = Alamofire.request(.GET, postLink)
            request.responseData { [unowned self] response in
                if response.result.isSuccess {
                    guard let str = response.data?.stringFromGB18030Data() else { errorHandler?() ; return }
                    fetchedImages = self.readImageLinks(str)
                    completionHandler?(fetchedImages)
                }
                else {
                    errorHandler?()
                }
            }
        }
    }

    func readImageLinks(str: String) -> [String] {
        var fetchedImages = [String]()
        let xpath: String = ( (self.forumID == DaguerreForumID) ? "//input" : "//img" )
        do {
            let document = try HTMLDocument(string: str.htmlEncodingCleanup())
            let elements = document.xpath(xpath)
            for element in elements {
                if self.forumID != DaguerreForumID && element["onload"] == nil { continue }
                guard var imageLink = element["src"] else { continue }
                imageLink = imageLink.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet)!
                fetchedImages.append(imageLink)
            }
        }
        catch _ {}
        return fetchedImages
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

    // MARK: Settings
    func settingsViewControllerDidEnd(sender: IASKAppSettingsViewController!) {
        sender.dismissViewControllerAnimated(true) {}
    }
    
    func settingsViewController(sender: IASKAppSettingsViewController!, buttonTappedForSpecifier specifier: IASKSpecifier!) {
        if specifier.key() == PasscodeLockConfig {
            let repository = UserDefaultsPasscodeRepository()
            let configuration = PasscodeLockConfiguration(repository: repository)
            if !repository.hasPasscode {
                let passcodeVC = PasscodeLockViewController(state: .SetPasscode, configuration: configuration)
                passcodeVC.successCallback = { lock in
                    let status = localizedString("On", comment: "打开")
                    saveValue(status, forKey: PasscodeLockStatus)
                }
                passcodeVC.dismissCompletionCallback = {
                    sender.tableView.reloadData()
                }
                sender.navigationController?.pushViewController(passcodeVC, animated: true)
            }
            else {
                let alert = UIAlertController(title: localizedString("Disable passcode", comment: "Disable passcode lock alert title"), message: localizedString("You are going to disable passcode lock. Continue?", comment: "Disable passcode lock alert body"), preferredStyle: .Alert)
                let confirmAction = UIAlertAction(title: localizedString("Continue", comment: "继续"), style: .Default, handler: { _ in
                    let passcodeVC = PasscodeLockViewController(state: .RemovePasscode, configuration: configuration)
                    passcodeVC.successCallback = { lock in
                        lock.repository.deletePasscode()
                        let status = localizedString("Off", comment: "关闭")
                        saveValue(status, forKey: PasscodeLockStatus)
                    }
                    passcodeVC.dismissCompletionCallback = {
                        sender.tableView.reloadData()
                    }
                    sender.navigationController?.pushViewController(passcodeVC, animated: true)
                })
                alert.addAction(confirmAction)
                let cancelAction = UIAlertAction(title: localizedString("Cancel", comment: "取消"), style: .Cancel, handler: nil)
                alert.addAction(cancelAction)
                sender.presentViewController(alert, animated: true, completion: nil)
            }
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

    // MARK: - Shake
    override func motionBegan(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == .MotionShake {
            let alert = UIAlertController(title: localizedString("Shake Detected", comment: "Shake Detected"), message: localizedString("Do you want to save all the preloaded posts' pictures? \nThis sometimes may take a long time!!!", comment: "Do you want to save all the preloaded posts' pictures? \nThis sometimes may take a long time!!!"), preferredStyle: .Alert)
            let saveAllAction = UIAlertAction(title: localizedString("Save All", comment: "Save All"), style: .Default, handler: { [unowned self] (_) in
                let hud = showHUD()
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { [unowned self] in
                    for post in self.posts {
                        if post.progress == 1.0 && !post.imageCached {
                            self.fetchImageLinks(fromPostLink: post.link, async: false, completionHandler: {
                                saveCachedLinksToHomeDirectory($0, forPostLink: post.link)
                            })
                        }
                    }
                    dispatch_async(dispatch_get_main_queue()) {
                        self.tableView.reloadData()
                        hud.hide()
                    }
                })
            })
            alert.addAction(saveAllAction)
            let cancelAction = UIAlertAction(title: localizedString("Cancel", comment: "Cancel"), style: .Cancel, handler: nil)
            alert.addAction(cancelAction)
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
}

