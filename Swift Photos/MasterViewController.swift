//
//  MasterViewController.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import Alamofire
import MWPhotoBrowser
import PKHUD
import InAppSettingsKit
import SDWebImage
import PasscodeLock
import Fuzi

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class MasterViewController: UITableViewController, IASKSettingsDelegate, MWPhotoBrowserDelegate, UISearchControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    var posts:[Post] = [Post]()
    var filteredPosts:[Post] = [Post]()
    var images:[String] = [String]()
    var page = 1
    var forumID = DaguerreForumID {
        didSet {
            self.resultsController?.forumID = forumID
        }
    }
    var daguerreLink:String = ""
    var mimiLink:String = ""
    var currentTitle:String = ""
    var currentCLLink:String = ""
    var settingsViewController:IASKAppSettingsViewController!
    var searchController:UISearchController!
    var resultsController:SearchResultController!
    var myActivity : NSUserActivity!
    fileprivate var preloadItem : UIBarButtonItem?
    @IBOutlet weak var editButton : UIBarButtonItem?
    fileprivate var settingsController : UIViewController?

    let categories = [NSLocalizedString("Daguerre's Flag", comment: "達蓋爾的旗幟"): 16,
                      NSLocalizedString("Young Beauty", comment: "唯美贴图"): 53,
                      NSLocalizedString("Sexy Beauty", comment: "激情贴图"): 70,
                      NSLocalizedString("Cam Shot", comment: "走光偷拍"): 81,
                      NSLocalizedString("Selfies", comment: "网友自拍"): 59,
                      NSLocalizedString("Hentai Manga", comment: "动漫漫画"): 46,
                      NSLocalizedString("Celebrities", comment: "明星八卦"): 79,
                      NSLocalizedString("Alternatives", comment: "另类贴图"): 60]

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

        let selectAllItems = UIBarButtonItem(title: NSLocalizedString("Select all", comment: "Select all"), style: .plain, target: self, action: #selector(MasterViewController.selectAllCells(_:)))
        let deselectAllItems = UIBarButtonItem(title: NSLocalizedString("Deselect all", comment: "Deselect all"), style: .plain, target: self, action: #selector(MasterViewController.deselectAllCells(_:)))
        let flexSpaceToolbarItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        preloadItem = UIBarButtonItem(title: NSLocalizedString("Batch preload", comment: "Batch preload"), style: .plain, target: self, action: #selector(MasterViewController.batchPreload(_:)))
        preloadItem!.isEnabled = false
        preloadItem!.tintColor = mainThemeColor()
        selectAllItems.tintColor = mainThemeColor()
        deselectAllItems.tintColor = mainThemeColor()
        navigationController?.isToolbarHidden = true
        setToolbarItems([deselectAllItems, selectAllItems, flexSpaceToolbarItem, preloadItem!], animated: true)

        loadFirstPageForKey(title!)
        
        tableView.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        // SearchBar
        resultsController = SearchResultController()
        resultsController.forumID = forumID
        searchController = UISearchController(searchResultsController: resultsController)
        searchController.searchResultsUpdater = resultsController
        let searchBar = searchController.searchBar
        self.tableView.tableHeaderView = searchBar
        searchBar.sizeToFit()
        searchBar.placeholder = NSLocalizedString("Search loaded posts", comment: "搜索已加载的帖子")

        navigationController?.navigationBar.barTintColor = mainThemeColor()
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.white]
        
        if #available(iOS 9, *) {
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }

        refreshControl = UIRefreshControl()
        refreshControl?.tintColor = mainThemeColor()
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: [.valueChanged])

        NotificationCenter.default.addObserver(self, selector: #selector(showNoMorePhotosHUD(_:)), name: NSNotification.Name(rawValue: MWPHOTO_NO_MORE_PHOTOS_NOTIFICATION), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MWPHOTO_NO_MORE_PHOTOS_NOTIFICATION), object: nil)
    }

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    func parseMimiLink() {
        let link = "ht" + "tps" + "://" + "ww" + "w" + ".ve" + "n" + "j" + "." + "m" + "e/m" + "m" + ".t" + "xt"
        let hud = PKHUD.sharedHUD
        hud.contentView = PKHUDTextView(text: NSLocalizedString("Parsing Daguerre Link...", comment: "HUD for parsing Daguerre's Flag link."))
        hud.show()
        let request = Alamofire.request(link)
        request.responseString { [unowned self] response in
            if response.result.isSuccess {
                guard let str = response.result.value else { return }
                self.mimiLink = str.strip().split(byCharacterSet: CharacterSet.newlines)[0].strip()
                let link = self.mimiLink + "forumdisplay.php?fid=\(self.forumID)"
                self.loadPostList(link, forPage: self.page)
            }
            else {
                hud.hide()
                hud.contentView = PKHUDTextView(text: NSLocalizedString("Network error", comment: "Network error happened, typically timeout."))
                hud.hide(afterDelay: 1)
            }
        }
    }
    
    func parseDaguerreLink() {
        let link = getDaguerreLink(self.forumID)
        let hud = PKHUD.sharedHUD
        hud.contentView = PKHUDTextView(text: NSLocalizedString("Parsing Daguerre Link...", comment: "HUD for parsing Daguerre's Flag link."))
        hud.show()
        let request = Alamofire.request(link + "index.php")
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
                hud.contentView = PKHUDTextView(text: NSLocalizedString("Network error", comment: "Network error happened, typically timeout."))
                hud.hide(afterDelay: 1)
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    func loadPostList(_ link:String, forPage page:Int) {
        if myActivity != nil {
            myActivity.invalidate()
        }
        if link != "" {
            myActivity = NSUserActivity(activityType: "me.venj.Swift-Photos.Continuity")
            myActivity.webpageURL = URL(string: link)
            myActivity.becomeCurrent()
        }

        let hud = showHUD()
        let l = link + "&page=\(self.page)"
        let request = Alamofire.request(l)
        request.responseData { [unowned self] response in
            if (response.result.isSuccess) {
                guard let str = response.data?.stringFromGB18030Data() else { return }
                let xpath: String = ( (self.forumID == DaguerreForumID) ? "//tr" : "//a" )
                do {
                    let document = try HTMLDocument(string: str.htmlEncodingCleanup())
                    let elements = document.xpath(xpath)
                    var indexPathes:[IndexPath] = []
                    let cellCount = self.posts.count
                    var i = 0
                    for e in elements {
                        var element = e
                        if self.forumID == DaguerreForumID {
                            if e.stringValue.contains("↑") { continue }
                            guard let elem = e.css("td h3 a").first else { continue }
                            element = elem
                        }
                        guard let link = element["href"] else { continue }
                        let filterString = ( (self.forumID == DaguerreForumID) ? "htm_data" : "viewthread.php" )
                        guard let _ = link.range(of: filterString) else { continue }
                        let title = element.stringValue
                        //FIXME: 4 is much based on experience
                        if title.count < 4 { continue }
                        self.posts.append(Post(title: title, link: getDaguerreLink(self.forumID) + link))
                        // Note the i++ here. It is much of a hack just for save one line.
                        indexPathes.append(IndexPath(row: cellCount + i, section: 0))
                        i += 1
                    }
                    self.resultsController.posts = self.posts // Assignment
                    self.tableView.insertRows(at: indexPathes, with: .top)
                    self.page += 1
                    hud.hide()
                }
                catch _ {
                    hud.hide() // If any exception, hide the hud
                }

                self.refreshControl?.endRefreshing()
            }
            else {
                hud.hide()
                DispatchQueue.main.async {
                    hud.contentView = PKHUDTextView(text: NSLocalizedString("Request timeout.", comment: "Request timeout hud."))
                    hud.hide(afterDelay: 1.0)
                    self.refreshControl?.endRefreshing()
                }
            }
        }
    }
    
    func loadPostListForPage(_ page:Int) {
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
            if mimiLink == "" {
                self.parseMimiLink()
            }
            else {
                link = mimiLink + "forumdisplay.php?fid=\(forumID)"
                loadPostList(link, forPage: page)
            }
        }
    }
    
    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }


    internal override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ProgressTableViewCell

        cell.textLabel?.text = posts[(indexPath as NSIndexPath).row].title
        cell.textLabel?.backgroundColor = UIColor.clear
        let post = posts[(indexPath as NSIndexPath).row]
        if post.imageCached {
            cell.textLabel?.textColor = UIColor.blue
        }
        else {
            cell.textLabel?.textColor = UIColor.black
        }
        cell.progress = post.progress
        cell.indentationWidth = -15.0
        return cell
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            preloadItem?.isEnabled = tableView.indexPathsForSelectedRows?.count > 0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            preloadItem?.isEnabled = true
            return
        }
        else {
            preloadItem?.isEnabled = false
        }
        tableView.deselectRow(at: indexPath, animated: true)
        guard let link = posts[(indexPath as NSIndexPath).row].link else { return }
        self.images = [String]()
        // Continuity for both local and remote data
        if let url = URL(string: link) {
            self.myActivity = NSUserActivity(activityType: "me.venj.Swift-Photos.Continuity")
            self.myActivity.webpageURL = url
            self.myActivity.becomeCurrent()
        }
        // Local Data
        if imagesCached(forPostLink: link) {
            let localDir = localDirectoryForPost(link, create: false)
            let basePath = URL(fileURLWithPath: localDir!).absoluteString
            let fm = FileManager.default
            var images : [String] = [String]()
            let files = try! fm.contentsOfDirectory(atPath: localDir!)
            for f in files {
                images.append(basePath.vc_stringByAppendingPathComponent(f as String))
            }
            self.images = images.sorted { (a, b) -> Bool in
                let nameA = Int(a.components(separatedBy: "/").last!)
                let nameB = Int(b.components(separatedBy: "/").last!)
                return nameA < nameB ? true : false
            }
            let photoBrowser = MWPhotoBrowser(delegate: self)
            self.currentTitle = tableView.cellForRow(at: indexPath)!.textLabel!.text!
            photoBrowser?.displayActionButton = true
            photoBrowser?.zoomPhotosToFill = false
            photoBrowser?.displayNavArrows = true
            self.navigationController?.pushViewController(photoBrowser!, animated: true)
        }
        else {
            //remote data
            let hud = showHUD()
            fetchImageLinks(fromPostLink: link, completionHandler: { [unowned self] fetchedImages in
                hud.hide()
                self.tableView.deselectRow(at: indexPath, animated: true)
                // Skip non pics
                if fetchedImages.count == 0 {
                    return
                }
                // prefetch images
                self.fetchImagesToCache(fetchedImages, withProgressAction: { (progress) in })
                self.images = fetchedImages
                let aCell:UITableViewCell = tableView.cellForRow(at: indexPath)!
                self.currentTitle = aCell.textLabel!.text!
                let photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser?.displayActionButton = true
                photoBrowser?.zoomPhotosToFill = false
                photoBrowser?.displayNavArrows = true
                self.navigationController?.pushViewController(photoBrowser!, animated: true)
                if self.myActivity != nil {
                    self.myActivity.invalidate()
                }
            },
            errorHandler: {
                hud.hide()
                DispatchQueue.main.async(execute: {
                    hud.contentView = PKHUDTextView(text:NSLocalizedString("Request timeout.", comment: "Request timeout hud."))
                    hud.hide(afterDelay: 1.0)
                })
            })
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).row == posts.count - 1 {
            loadPostListForPage(page)
        }
        
        // Seperator inset fix from Stack Overflow: http://stackoverflow.com/questions/25770119/ios-8-uitableview-separator-inset-0-not-working
        // iOS 8 and up
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets.zero
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if ((indexPath as NSIndexPath).row < 0) { return nil }
        let post = posts[(indexPath as NSIndexPath).row]
        if !post.imageCached {
            // Preload
            let preloadAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: NSLocalizedString("Preload", comment: "Preload Button.")) { [unowned self] (_, indexPath) in
                self.preloadIndexPath(indexPath)
            }
            preloadAction.backgroundColor = UIColor.magenta
            //Save
            let link = post.link
            let saveAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: NSLocalizedString("Save", comment: "Save Button.")) { [unowned self] (_, indexPath) in
                let cell = tableView.cellForRow(at: indexPath)!
                let spinWheel = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                cell.accessoryView = spinWheel
                spinWheel.startAnimating()

                self.fetchImageLinks(fromPostLink: link!, completionHandler: { [unowned self] fetchedImages in
                    saveCachedLinksToHomeDirectory(fetchedImages, forPostLink: link!)
                    self.tableView.reloadData()
                    spinWheel.stopAnimating()
                    cell.accessoryView = nil
                }, errorHandler: {
                    spinWheel.stopAnimating()
                    cell.accessoryView = nil
                })

                if tableView.isEditing {
                    tableView.setEditing(false, animated: true)
                }
            }
            saveAction.backgroundColor = UIColor.orange
            return [preloadAction, saveAction]
        }
        else {
            // Reset cache
            let link = post.link
            let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: NSLocalizedString("Delete", comment: "Delete")) { [unowned self] (_, indexPath) in
                let hud = showHUD()
                self.removeImagesForLink(link!, completionHandler: {
                    hud.hide()
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(1_000_000) / Double(NSEC_PER_SEC), execute: {
                        post.progress = 0
                        self.tableView.reloadData()
                    })
                })

                if tableView.isEditing {
                    tableView.setEditing(false, animated: true)
                }
            }
            deleteAction.backgroundColor = UIColor.red
            return [deleteAction]
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) { }

    // MARK: MWPhotoBrowser Delegate
    func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(images.count)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        let p = MWPhoto(url: URL(string: images[Int(index)]))
        p?.caption = "(\(index + 1)/\(images.count)) " + currentTitle
        return p
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, titleForPhotoAt index: UInt) -> String! {
        let t:NSMutableString = self.currentTitle.mutableCopy() as! NSMutableString
        let range = t.range(of: "[", options:.backwards)
        if range.location != NSNotFound {
            t.insert("\(index + 1)/", at: range.location + 1)
            return t as String
        }
        return self.currentTitle
    }
    
    // MARK: - Actions
    @IBAction func showSections(_ sender: Any?) {
        let sectionsController = UIAlertController(title: NSLocalizedString("Please select a category", comment: "ActionSheet title."), message: "", preferredStyle: .actionSheet)
        sectionsController.popoverPresentationController?.delegate = self

        for key in categories.keys {
            let act = UIAlertAction(title: key, style: .default, handler: { [unowned self] _ in
                saveValue(key, forKey: LastViewedSectionTitle)
                self.title = key
                self.loadFirstPageForKey(key)
            })
            sectionsController.addAction(act)
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button. (General)"), style: .cancel, handler: nil)
        sectionsController.addAction(cancelAction)
        self.present(sectionsController, animated: true) {
            sectionsController.popoverPresentationController?.passthroughViews = nil
        }
    }
    
    @IBAction func showSettings(_ action: UIAlertAction) {
        if getValue(CurrentCLLinkKey) == nil {
            _ = getDaguerreLink(self.forumID)
        }

        let hud = showHUD()
        SDImageCache.shared().calculateSize() { [unowned self] (fileCount:UInt, totalSize:UInt) in
            let humanReadableSize = NSString(format: "%.1f MB", Double(totalSize) / (1024 * 1024))
            saveValue(humanReadableSize, forKey: ImageCacheSizeKey)

            let passcodeRepo = UserDefaultsPasscodeRepository()
            let status = passcodeRepo.hasPasscode ? NSLocalizedString("On", comment: "打开") : NSLocalizedString("Off", comment: "关闭")
            saveValue(status, forKey: PasscodeLockStatus)
            
            self.settingsViewController = IASKAppSettingsViewController(style: .grouped)
            self.settingsViewController.delegate = self
            self.settingsViewController.showCreditsFooter = false
            let settingsNavigationController = UINavigationController(rootViewController: self.settingsViewController)
            settingsNavigationController.navigationBar.barTintColor = mainThemeColor()
            settingsNavigationController.navigationBar.tintColor = UIColor.white
            settingsNavigationController.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.white]
            settingsNavigationController.modalPresentationStyle = .formSheet
            self.present(settingsNavigationController, animated: true) {}
            hud.hide()
        }
    }

    @IBAction func showEdit(_ sender: Any?) {
        if !tableView.isEditing {
            tableView.setEditing(true, animated: true)
            preloadItem?.isEnabled = false
            editButton?.title = NSLocalizedString("Done", comment: "完成")
            navigationController?.setToolbarHidden(false, animated: true)
        }
        else {
            exitEdit()
        }
    }

    @objc func batchPreload(_ sender: UIBarButtonItem?) {
        let indexPaths = tableView.indexPathsForSelectedRows
        exitEdit()
        indexPaths?.forEach(preloadIndexPath)
    }

    @objc func selectAllCells(_ sender: UIBarButtonItem?) {
        if tableView.isEditing {
            for i in 0 ..< posts.count {
                let indexPath = IndexPath(row: i, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
            preloadItem?.isEnabled = true
        }
    }

    @objc func deselectAllCells(_ sender: UIBarButtonItem?) {
        if tableView.isEditing {
            for i in 0 ..< posts.count {
                let indexPath = IndexPath(row: i, section: 0)
                tableView.deselectRow(at: indexPath, animated: false)
            }
            preloadItem?.isEnabled = false
        }
    }

    func exitEdit() {
        navigationController?.setToolbarHidden(true, animated: true)
        tableView.setEditing(false, animated: true)
        editButton?.title = NSLocalizedString("Edit", comment: "编辑")
    }

    @objc func showNoMorePhotosHUD(_ notification: Notification) {
        showHudWithMessage(NSLocalizedString("No more photos.", comment: "No more photos."));
    }

    @objc func refresh(_ sender:AnyObject?) {
        let key = title
        currentCLLink = getDaguerreLink(self.forumID)
        let range = daguerreLink.range(of: currentCLLink)
        if self.forumID == DaguerreForumID && range == nil {
            parseDaguerreLink()
        }
        else {
            loadFirstPageForKey(key!)
        }
    }

    // MARK: - UIPopoverPresentationControllerDelegate
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
        popoverPresentationController.barButtonItem = navigationItem.rightBarButtonItem
    }

    // MARK: Helper
    func loadFirstPageForKey(_ key:String) {
        if tableView.isEditing {
            tableView.setEditing(false, animated: false)
        }
        forumID = categories[key]!
        posts = [Post]()
        page = 1
        tableView.reloadData()
        loadPostListForPage(page)
    }
    
    func recalculateCacheSize() {
        let size = SDImageCache.shared().getSize()
        let humanReadableSize = NSString(format: "%.1f MB", Double(size) / (1024 * 1024))
        saveValue(humanReadableSize, forKey: ImageCacheSizeKey)
    }
    
    func fetchImageLinks(fromPostLink postLink:String, async: Bool = true, completionHandler:(([String]) -> Void)? = nil, errorHandler:(() -> Void)? = nil) {
        var fetchedImages = [String]()
        if !async {
            guard let url = URL(string: postLink) else { return }
            let data = try? Data(contentsOf: url)
            guard let str = data?.stringFromGB18030Data() else { return }
            fetchedImages = readImageLinks(str)
            completionHandler?(fetchedImages)
        }
        else {
            let request = Alamofire.request(postLink)
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

    func removeImagesForLink(_ link:String, completionHandler:(() -> Void)? = nil, errorHandler:(() -> Void)? = nil) {
        // Remove saved images
        guard let localPath = localDirectoryForPost(link) else { return }
        let fm = FileManager.default
        var isDir:ObjCBool = false
        let dirExists = fm.fileExists(atPath: localPath, isDirectory: &isDir)
        if dirExists && isDir.boolValue {
            do {
                try fm.removeItem(atPath: localPath)
            }
            catch _ {}
        }

        // Remove image cache.
        var fetchedImages = [String]()
        let request = Alamofire.request(link)
        request.responseData { [unowned self] response in
            if response.result.isSuccess {
                guard let str = response.data?.stringFromGB18030Data() else { errorHandler?() ; return }
                fetchedImages = self.readImageLinks(str)
                for imageLink in fetchedImages {
                    let key = SDWebImageManager.shared().cacheKey(for: URL(string: imageLink))
                    SDImageCache.shared().removeImage(forKey: key)
                }
                completionHandler?()
            }
            else {
                errorHandler?()
            }
        }
    }

    func readImageLinks(_ str: String) -> [String] {
        var fetchedImages = [String]()
        let xpath: String = ( (self.forumID == DaguerreForumID) ? "//input" : "//img" )
        do {
            let document = try HTMLDocument(string: str.htmlEncodingCleanup())
            let elements = document.xpath(xpath)
            for element in elements {
                if self.forumID != DaguerreForumID && element["onload"] == nil { continue }
                guard var imageLink = element["src"] else { continue }
                imageLink = imageLink.addingPercentEncoding(withAllowedCharacters: CharacterSet.whitespacesAndNewlines.inverted)!
                guard let _ = NSURL(string: imageLink) else { continue }
                fetchedImages.append(imageLink)
            }
        }
        catch _ {}
        return fetchedImages
    }

    func setDefaultTitle() {
        title = NSLocalizedString("Young Beauty", comment: "唯美贴图")
    }
    
    // Don't care if the request is succeeded or not.
    func fetchImagesToCache(_ images:[String], withProgressAction progressAction:((Float) -> Void)? ) {
        var downloadedImagesCount = 0
        let totalImagesCount = images.count
        for image in images {
            SDWebImageManager.shared().cachedImageExists(for: URL(string: image), completion: { (result) in
                if result {
                    downloadedImagesCount += 1
                    let progress = Float(downloadedImagesCount) / Float(totalImagesCount)
                    progressAction?(progress)
                }
                else {
                    let imageLink = image.addingPercentEncoding(withAllowedCharacters: CharacterSet.whitespacesAndNewlines.inverted)!

                    let fileURL: URL = URL(fileURLWithPath: localImagePath(image))
                    let destination: DownloadRequest.DownloadFileDestination = { _, _ in
                        return (fileURL, [.createIntermediateDirectories, .removePreviousFile])
                    }

                    Alamofire.download(imageLink, method: .get, to: destination)
                        .downloadProgress(queue: DispatchQueue.global()) { progress in
                            //print("Progress: \(progress.fractionCompleted)")
                            if (progress.fractionCompleted == 1.0) {
                                downloadedImagesCount += 1
                                let progress = Float(downloadedImagesCount) / Float(totalImagesCount)
                                progressAction?(progress)
                            }
                        }
                        .validate { request, response, temporaryURL, destinationURL in
                            return .success
                    }
                }
            })
        }
    }
    
    func cacheImages(forIndexPath indexPath: IndexPath, withProgressAction progressAction:@escaping (Float) -> Void) {
        let link = posts[(indexPath as NSIndexPath).row].link
        fetchImageLinks(fromPostLink: link!, completionHandler: { [unowned self] fetchedImages in
            self.tableView.deselectRow(at: indexPath, animated: true)
            // Skip non pics
            if fetchedImages.count == 0 {
                return
            }
            // prefetch images
            self.fetchImagesToCache(fetchedImages, withProgressAction:progressAction)
        },
        errorHandler: nil)
    }

    private func preloadIndexPath(_ indexPath: IndexPath) {
        cacheImages(forIndexPath: indexPath, withProgressAction: { [unowned self] (progress) in
            // Update Progress.
            // FIXME: If the cell is preloading, and we switch to another section, the progress will keep updating.
            guard let cell = self.tableView.cellForRow(at: indexPath) as? ProgressTableViewCell else { return }
            let post = self.posts[(indexPath as NSIndexPath).row]
            post.progress = progress
            DispatchQueue.main.async(execute: {
                cell.progress = progress
            })
        })
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
        }
    }

    // MARK: - Settings
    func settingsViewControllerDidEnd(_ sender: IASKAppSettingsViewController!) {
        sender.dismiss(animated: true) {}
    }
    
    func settingsViewController(_ sender: IASKAppSettingsViewController!, buttonTappedFor specifier: IASKSpecifier!) {
        if specifier.key() == PasscodeLockConfig {
            let repository = UserDefaultsPasscodeRepository()
            let configuration = PasscodeLockConfiguration(repository: repository)
            if !repository.hasPasscode {
                let passcodeVC = PasscodeLockViewController(state: .setPasscode, configuration: configuration)
                passcodeVC.successCallback = { lock in
                    let status = NSLocalizedString("On", comment: "打开")
                    saveValue(status, forKey: PasscodeLockStatus)
                }
                passcodeVC.dismissCompletionCallback = {
                    sender.tableView.reloadData()
                }
                sender.navigationController?.pushViewController(passcodeVC, animated: true)
            }
            else {
                let alert = UIAlertController(title: NSLocalizedString("Disable passcode", comment: "Disable passcode lock alert title"), message: NSLocalizedString("You are going to disable passcode lock. Continue?", comment: "Disable passcode lock alert body"), preferredStyle: .alert)
                let confirmAction = UIAlertAction(title: NSLocalizedString("Continue", comment: "继续"), style: .default, handler: { _ in
                    let passcodeVC = PasscodeLockViewController(state: .removePasscode, configuration: configuration)
                    passcodeVC.successCallback = { lock in
                        lock.repository.deletePasscode()
                        let status = NSLocalizedString("Off", comment: "关闭")
                        saveValue(status, forKey: PasscodeLockStatus)
                    }
                    passcodeVC.dismissCompletionCallback = {
                        sender.tableView.reloadData()
                    }
                    sender.navigationController?.pushViewController(passcodeVC, animated: true)
                })
                alert.addAction(confirmAction)
                let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "取消"), style: .cancel, handler: nil)
                alert.addAction(cancelAction)
                sender.present(alert, animated: true, completion: nil)
            }
        }
        else if specifier.key() == ClearCacheNowKey {
            let hud = showHUD()
            SDImageCache.shared().clearDisk() { [unowned self] in
                self.recalculateCacheSize()
                DispatchQueue.main.async(execute: {
                    hud.contentView = PKHUDTextView(text: NSLocalizedString("Cache Cleared", comment: "缓存已清除"))
                    hud.hide(afterDelay: 1.0)
                    sender.tableView.reloadData()
                })
            }
        }
        else if specifier.key() == ClearDownloadCacheKey {
            let hud = showHUD()
            clearDownloadCache() {
                DispatchQueue.main.async(execute: {
                    hud.contentView = PKHUDTextView(text: NSLocalizedString("Cache Cleared", comment: "缓存已清除"))
                    hud.hide(afterDelay: 1.0)
                    sender.tableView.reloadData()
                })
            }
        }
        else if specifier.key() == CurrentCLLinkKey {
            // Load links from web.
            settingsController = sender
            fetchCLLinks({ (links) -> () in
                let linksController = CLLinksTableViewTableViewController(style:.grouped);
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

    func fetchCLLinks( _ complete: @escaping (_ links : [String]?)->() ) {
        let hud = showHUD()
        let textLink = "ht" + "tps" + "://" + "ww" + "w" + ".ve" + "n" + "j" + "." + "m" + "e/c" + "l.t" + "xt?\(Date().timeIntervalSince1970)"
        let request = Alamofire.request(textLink)
        request.responseString { (response) in
            if response.result.isSuccess {
                hud.hide()
                let str = response.result.value
                let links = str?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: ";")
                complete(links)
            }
            else {
                hud.hide()
                DispatchQueue.main.async {
                    hud.contentView = PKHUDTextView(text:NSLocalizedString("Request timeout.", comment: "Request timeout hud."))
                    hud.hide(afterDelay: 1.0)
                    complete([])
                }
            }
        }
    }

    func clearDownloadCache( _ complete: ()->() ) {
        let tempDir = NSTemporaryDirectory();
        //println(tempDir)
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: tempDir) {
            for item in contents {
                do {
                    try fm.removeItem(atPath: tempDir.vc_stringByAppendingPathComponent(item))
                } catch _ {
                }
            }
        }
        complete()
    }
    
    // MARK: UISearchResultUpdating
    func updateSearchResultsForSearchController(_ searchController: UISearchController) {
        filteredPosts.removeAll(keepingCapacity: true)
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        resultsController.forumID = self.forumID
    }

    // MARK: - Shake
    override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let alert = UIAlertController(title: NSLocalizedString("Shake Detected", comment: "Shake Detected"), message: NSLocalizedString("Do you want to save all the preloaded posts' pictures? \nThis sometimes may take a long time!!!", comment: "Do you want to save all the preloaded posts' pictures? \nThis sometimes may take a long time!!!"), preferredStyle: .alert)
            let saveAllAction = UIAlertAction(title: NSLocalizedString("Save All", comment: "Save All"), style: .default, handler: { [unowned self] (_) in
                let hud = showHUD()
                DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: { [unowned self] in
                    UIApplication.shared.isIdleTimerDisabled = true
                    for post in self.posts {
                        if post.progress == 1.0 && !post.imageCached {
                            self.fetchImageLinks(fromPostLink: post.link, async: false, completionHandler: {
                                saveCachedLinksToHomeDirectory($0, forPostLink: post.link)
                            })
                        }
                    }
                    UIApplication.shared.isIdleTimerDisabled = false
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                        hud.hide()
                    }
                })
            })
            alert.addAction(saveAllAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

