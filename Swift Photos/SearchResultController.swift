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
import Fuzi

class SearchResultController: UITableViewController, UISearchResultsUpdating, MWPhotoBrowserDelegate {
    
    let sectionTableIdentifier = "SectionTableIdentifier"
    var images:[String] = []
    internal var posts : [Post]!
    var filteredPosts : [Post] = []
    var currentTitle:String = ""
    var forumID = 16
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: sectionTableIdentifier)
        automaticallyAdjustsScrollViewInsets = false
        tableView.contentInset = UIEdgeInsetsMake(66.0, 0.0, 0.0, 0.0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredPosts.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: sectionTableIdentifier)!
        cell.textLabel?.text = filteredPosts[(indexPath as NSIndexPath).row].title
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        cell.accessoryType = .detailDisclosureButton
        
        let link = posts[(indexPath as NSIndexPath).row].link
        if imagesCached(forPostLink: link!) {
            cell.textLabel?.textColor = UIColor.blue
        }
        else {
            cell.textLabel?.textColor = UIColor.black
        }
        return cell
    }
    
    // MARK: - UISearchResultsUpdating
    func updateSearchResults(for searchController: UISearchController) {
        filteredPosts.removeAll(keepingCapacity: true)
        let searchString = searchController.searchBar.text
        for post in posts {
            guard let _ = post.title.range(of: searchString!, options: NSString.CompareOptions.caseInsensitive) else { continue }
            filteredPosts.append(post)
        }
        tableView.reloadData()
    }
    
    // MARK: - Table View Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let link = filteredPosts[(indexPath as NSIndexPath).row].link else { return }
        images = []
        // Local Data
        if imagesCached(forPostLink: link) {
            let localDir = localDirectoryForPost(link, create: false)
            let basePath = URL(fileURLWithPath: localDir!).absoluteString
            let fm = FileManager.default
            var images : [String] = []
            let files = try! fm.contentsOfDirectory(atPath: localDir!)
            for f in files {
                images.append(basePath.vc_stringByAppendingPathComponent(f as String))
            }
            self.images = images
            let photoBrowser = MWPhotoBrowser(delegate: self)
            photoBrowser?.displayActionButton = true
            photoBrowser?.zoomPhotosToFill = false
            photoBrowser?.displayNavArrows = true
            let nav = UINavigationController(rootViewController: photoBrowser!)
            present(nav, animated: true, completion: nil)
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
                self.fetchImagesToCache(fetchedImages)
                self.images = fetchedImages
                let aCell:UITableViewCell = tableView.cellForRow(at: indexPath)!
                self.currentTitle = aCell.textLabel!.text!
                let photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser?.displayActionButton = true
                photoBrowser?.zoomPhotosToFill = false
                photoBrowser?.displayNavArrows = true
                let nav = UINavigationController(rootViewController: photoBrowser!)
                self.present(nav, animated: true, completion: nil)
            },
            errorHandler: {
                hud.hide()
            })
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let link = posts[(indexPath as NSIndexPath).row].link else { return }

        let cell = tableView.cellForRow(at: indexPath)!
        let spinWheel = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        cell.accessoryView = spinWheel
        spinWheel.startAnimating()

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
    
    // Don't care if the request is succeeded or not.
    func fetchImagesToCache(_ images:[String]) {
        for image in images {
            if image == images[0] {
                // Skip the first pic.
                continue
            }
            SDWebImageManager.shared().cachedImageExists(for: URL(string: image), completion: { (result) in
                if result  {
                    //println("Cached")
                    return
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
                        }
                        .validate { request, response, temporaryURL, destinationURL in
                            return .success
                    }
                }
            })
        }
    }
    
    // MARK: MWPhotoBrowser Delegate
    func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(images.count)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        let p = MWPhoto(url: URL(string: images[Int(index)]))
        p?.caption = "\(index + 1)/\(images.count)"
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
}
