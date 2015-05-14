//
//  SearchResultController.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/12/16.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import Alamofire

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
        let cell = tableView.dequeueReusableCellWithIdentifier(sectionTableIdentifier) as! UITableViewCell
        cell.textLabel?.text = filteredPosts[indexPath.row].title
        cell.textLabel?.font = UIFont.boldSystemFontOfSize(17)
        cell.accessoryType = .DetailDisclosureButton
        
        let link = posts[indexPath.row].link
        if imagesCached(forPostLink: link) {
            cell.textLabel?.textColor = UIColor.blueColor()
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
            let range = post.title.rangeOfString(searchString, options: NSStringCompareOptions.CaseInsensitiveSearch)
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
            photoBrowser.displayActionButton = true
            photoBrowser.zoomPhotosToFill = false
            photoBrowser.displayNavArrows = true
            let nav = UINavigationController(rootViewController: photoBrowser)
            presentViewController(nav, animated: true, completion: nil)
        }
        else {
            //remote data
            let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
            fetchImageLinks(fromPostLink: link, completionHandler: { [weak self] fetchedImages in
                let strongSelf = self!
                hud.hide(true)
                strongSelf.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                // Skip non pics
                if fetchedImages.count == 0 {
                    return
                }
                // prefetch images
                strongSelf.fetchImagesToCache(fetchedImages)
                strongSelf.images = fetchedImages
                let aCell:UITableViewCell = tableView.cellForRowAtIndexPath(indexPath)!
                strongSelf.currentTitle = aCell.textLabel!.text!
                var photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser.displayActionButton = true
                photoBrowser.zoomPhotosToFill = false
                photoBrowser.displayNavArrows = true
                let nav = UINavigationController(rootViewController: photoBrowser)
                strongSelf.presentViewController(nav, animated: true, completion: nil)
            },
            errorHandler: {
                hud.hide(true)
            })
        }
    }
    
    override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)!
        let spinWheel = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        cell.accessoryView = spinWheel
        spinWheel.startAnimating()
        
        let link = posts[indexPath.row].link
        fetchImageLinks(fromPostLink: link, completionHandler: { [weak self] fetchedImages in
            let strongSelf = self!
            saveCachedLinksToHomeDirectory(fetchedImages, forPostLink: link)
            strongSelf.tableView.reloadData()
            spinWheel.stopAnimating()
            cell.accessoryView = nil
            }, errorHandler: {
                spinWheel.stopAnimating()
                cell.accessoryView = nil
        })
    }
    
    
    func fetchImageLinks(fromPostLink postLink:String, completionHandler:((Array<String>) -> Void), errorHandler:(() -> Void)) {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = requestTimeOutForWeb
        let manager = Alamofire.Manager(configuration: configuration)
        var request = manager.request(.GET, postLink)
        request.response { [weak self] (request, response, data, error) in
            let strongSelf = self!
            var fetchedImages = Array<String>()
            if error == nil {
                let d = data as! NSData
                var str:NSString = d.stringFromGB18030Data()
                var error:NSError?
                var regexString:String
                if strongSelf.forumID == 16 {
                    regexString = "input type='image' src='([^\"]+?)'"
                }
                else {
                    regexString = "img src=\"([^\"]+)\" .+? onload"
                }
                var regex = NSRegularExpression(pattern: regexString, options: .CaseInsensitive, error: &error)
                let matches = regex!.matchesInString(str as String, options: nil, range: NSMakeRange(0, str.length))
                for match in matches {
                    let imageLink = str.substringWithRange(match.rangeAtIndex(1))
                    fetchedImages.append(imageLink)
                }
                completionHandler(fetchedImages)
            }
            else {
                // Handle error
                errorHandler()
            }
        }
    }
    
    // Don't care if the request is succeeded or not.
    func fetchImagesToCache(images:[String]) {
        var image = ""
        let path = ""
        for image in images {
            if image == images[0] {
                // Skip the first pic.
                continue
            }
            if SDWebImageManager.sharedManager().cachedImageExistsForURL(NSURL(string: image)) {
                //println("Cached")
                continue
            }
            let imageLink = image.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            configuration.timeoutIntervalForRequest = requestTimeOutForWeb
            let manager = Alamofire.Manager(configuration: configuration)
            manager.download(.GET, imageLink, destination: { (temporaryURL, response) in
                // 返回下载目标路径的 fileURL
                let imageURL = NSURL.fileURLWithPath(localImagePath(image))
                if let directory = imageURL {
                    return directory
                }
                return temporaryURL
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
    

}
