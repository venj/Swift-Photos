//
//  SearchResultController.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/12/16.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import Alamofire
import MWPhotoBrowser
import SDWebImage

class SearchResultController: UITableViewController, UISearchResultsUpdating, MWPhotoBrowserDelegate {
    
    let sectionTableIdentifier = "SectionTableIdentifier"
    var images:[String] = []
    internal var posts : [Post]!
    var filteredPosts : [Post] = []
    var currentTitle:String = ""
    var forumID = 16
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: sectionTableIdentifier)
        self.automaticallyAdjustsScrollViewInsets = false
        tableView.contentInset = UIEdgeInsetsMake(66.0, 0.0, 0.0, 0.0)

        if #available(iOS 9, *) {
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredPosts.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(sectionTableIdentifier)!
        cell.textLabel?.text = filteredPosts[indexPath.row].title
        cell.textLabel?.font = UIFont.boldSystemFontOfSize(17)
        cell.accessoryType = .DetailDisclosureButton
        
        let link = posts[indexPath.row].link
        if imagesCached(forPostLink: link) {
            cell.textLabel?.textColor = UIColor.iOS8darkBlueColor()
        }
        else {
            cell.textLabel?.textColor = UIColor.blackColor()
        }
        return cell
    }
    
    // MARK: - UISearchResultsUpdating
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        filteredPosts.removeAll(keepCapacity: true)
        let searchString = searchController.searchBar.text
        for post in posts {
            let range = post.title.rangeOfString(searchString!, options: NSStringCompareOptions.CaseInsensitiveSearch)
            if range != nil {
                self.filteredPosts.append(post)
            }
        }
        self.tableView.reloadData()
    }
    
    // MARK: - Table View Delegate
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let link = posts[indexPath.row].link
        self.images = []
        // Local Data
        if imagesCached(forPostLink: link) {
            let localDir = localDirectoryForPost(link, create: false)
            let basePath = NSURL(fileURLWithPath: localDir!).absoluteString
            let fm = NSFileManager.defaultManager()
            var images : [String] = []
            let files = try! fm.contentsOfDirectoryAtPath(localDir!)
            for f in files {
                images.append(basePath.vc_stringByAppendingPathComponent(f as String))
            }
            self.images = images
            let photoBrowser = MWPhotoBrowser(delegate: self)
            photoBrowser.displayActionButton = true
            photoBrowser.zoomPhotosToFill = false
            photoBrowser.displayNavArrows = true
            let nav = UINavigationController(rootViewController: photoBrowser)
            presentViewController(nav, animated: true, completion: nil)
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
                self.fetchImagesToCache(fetchedImages)
                self.images = fetchedImages
                let aCell:UITableViewCell = tableView.cellForRowAtIndexPath(indexPath)!
                self.currentTitle = aCell.textLabel!.text!
                let photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser.displayActionButton = true
                photoBrowser.zoomPhotosToFill = false
                photoBrowser.displayNavArrows = true
                let nav = UINavigationController(rootViewController: photoBrowser)
                self.presentViewController(nav, animated: true, completion: nil)
            },
            errorHandler: {
                hud.hide()
            })
        }
    }
    
    override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)!
        let spinWheel = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        cell.accessoryView = spinWheel
        spinWheel.startAnimating()
        
        let link = posts[indexPath.row].link
        fetchImageLinks(fromPostLink: link, completionHandler: { [unowned self] fetchedImages in
            saveCachedLinksToHomeDirectory(fetchedImages, forPostLink: link)
            self.tableView.reloadData()
            spinWheel.stopAnimating()
            cell.accessoryView = nil
            }, errorHandler: {
                spinWheel.stopAnimating()
                cell.accessoryView = nil
        })
    }
    
    
    func fetchImageLinks(fromPostLink postLink:String, completionHandler:(([String]) -> Void)?, errorHandler:(() -> Void)?) {
        let request = Alamofire.request(.GET, postLink)
        request.responseData { [unowned self] response in
            var fetchedImages = [String]()
            if response.result.isSuccess {
                guard let str = response.data?.stringFromGB18030Data() else { errorHandler?() ; return }
                var regexString:String
                if self.forumID == 16 {
                    regexString = "input type='image' src='([^\"]+?)'"
                }
                else {
                    regexString = "img src=\"([^\"]+)\" .+? onload"
                }
                do {
                    let regex = try NSRegularExpression(pattern: regexString, options: .CaseInsensitive)
                    let matches = regex.matchesInString(str, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, str.characters.count))
                    for match in matches {
                        let imageLink = str.substringWithRange(str.rangeFromNSRange(match.rangeAtIndex(1)))
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
    
    // Don't care if the request is succeeded or not.
    func fetchImagesToCache(images:[String]) {
        for image in images {
            if image == images[0] {
                // Skip the first pic.
                continue
            }
            if SDWebImageManager.sharedManager().cachedImageExistsForURL(NSURL(string: image)) {
                //println("Cached")
                continue
            }
            let imageLink = image.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet)!
            Alamofire.download(.GET, imageLink, destination: { (temporaryURL, response) in
                // 返回下载目标路径的 fileURL
                return NSURL.fileURLWithPath(localImagePath(image))
            }) // For Debug
                .progress { (bytesRead, totalBytesRead, totalBytesExpectedToRead) in
                    //if totalBytesRead == totalBytesExpectedToRead {
                    //    println("Done.")
                    //}
                } // For Debug
                .response { (request, response, _, error) in
                    //println(response)
            }
        }
    }
    
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
}
