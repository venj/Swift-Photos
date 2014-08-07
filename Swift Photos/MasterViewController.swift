//
//  MasterViewController.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController, MWPhotoBrowserDelegate, UIActionSheetDelegate {
    
    var posts:Array<Post> = []
    var images:Array<String> = []
    var page = 1
    var forumID = 53
    
    let categories = [NSLocalizedString("Young Beauty", tableName: nil, value: "Young Beauty", comment: "唯美贴图"): 53,
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
        title = NSLocalizedString("Young Beauty", tableName: nil, value: "Young Beauty", comment: "唯美贴图")
        loadFirstPageForKey(title)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loatPostListForPage(page:Int) {
        let hud = MBProgressHUD.showHUDAddedTo(navigationController.view, animated: true)
        var request = Alamofire.request(.GET, baseLink + "forumdisplay.php?fid=\(forumID)&page=\(page)")
        request.response { [weak self] (request, response, data, error) in
            var strongSelf = self!
            if data == nil {
                hud.hide(true)
                var messageHUD = MBProgressHUD.showHUDAddedTo(strongSelf.navigationController.view, animated: true)
                messageHUD.mode = MBProgressHUDModeCustomView
                messageHUD.labelText = NSLocalizedString("No data received. iOS 7 user?", tableName: nil, value: "No data received. iOS 7 user?", comment: "HUD when no data received.")
                messageHUD.hide(true, afterDelay: 2.0)
                return
            }
            if error == nil {
                let d = data as NSData
                var str:NSString = d.stringFromGBKData()
                var error:NSError?
                var regex = NSRegularExpression(pattern: "<a href=\"(viewthread\\.php[^\"]+?)\">([^\\d<]+?\\d+[^\\d]+?)</a>", options: .CaseInsensitive, error: &error)
                let matches = regex.matchesInString(str, options: nil, range: NSMakeRange(0, str.length))
                var indexPathes:Array<NSIndexPath> = []
                var cellCount = strongSelf.posts.count
                for var i = 0; i < matches.count; ++i {
                    let match: AnyObject = matches[i]
                    let link = baseLink + str.substringWithRange(match.rangeAtIndex(1))
                    let title = str.substringWithRange(match.rangeAtIndex(2))
                    strongSelf.posts.append(Post(title: title, link: link))
                    indexPathes.append(NSIndexPath(forRow:cellCount + i, inSection: 0))
                }
                hud.hide(true)
                strongSelf.tableView.insertRowsAtIndexPaths(indexPathes, withRowAnimation:.Top)
                strongSelf.page++
            }
            else {
                // Handle error
                hud.hide(true)
            }
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
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell

        cell.textLabel.text = posts[indexPath.row].title
        return cell
    }
    
    override func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        let indexPath = tableView.indexPathForSelectedRow()
        
        let hud = MBProgressHUD.showHUDAddedTo(navigationController.view, animated: true)
        var request = Alamofire.request(.GET, posts[indexPath.row].link)
        request.response { [weak self] (request, response, data, error) in
            var strongSelf = self!
            strongSelf.images = []
            if error == nil {
                let cp936 = CFStringConvertWindowsCodepageToEncoding(936)
                let gbkEncoding:NSStringEncoding = CFStringConvertEncodingToNSStringEncoding(cp936);
                var str = NSString(data: data as NSData, encoding: gbkEncoding)
                var error:NSError?
                var regex = NSRegularExpression(pattern: "img src=\"([^\"]+)\" .+? onload", options: .CaseInsensitive, error: &error)
                let matches = regex.matchesInString(str, options: nil, range: NSMakeRange(0, str.length))
                for match in matches {
                    let imageLink = str.substringWithRange(match.rangeAtIndex(1))
                    strongSelf.images.append(imageLink)
                }
                
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
                hud.hide(true)
                
                // Skip non pics
                if strongSelf.images.count == 0 {
                    return
                }
                var photoBrowser = MWPhotoBrowser(delegate: self)
                photoBrowser.displayActionButton = false
                photoBrowser.zoomPhotosToFill = false
                strongSelf.navigationController.pushViewController(photoBrowser, animated: true)
            }
            else {
                // Handle error
                hud.hide(true)
            }
        }
    }
    
    override func tableView(tableView: UITableView!, willDisplayCell cell: UITableViewCell!, forRowAtIndexPath indexPath: NSIndexPath!) {
        if indexPath.row == posts.count - 1 {
            loatPostListForPage(page)
        }
    }
    
    // MARK: MWPhotoBrowser Delegate
    func numberOfPhotosInPhotoBrowser(photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(images.count)
    }
    
    func photoBrowser(photoBrowser: MWPhotoBrowser!, photoAtIndex index: UInt) -> MWPhotoProtocol! {
        var p = MWPhoto(URL: NSURL(string: images[Int(index)]))
        return p
    }
    
    // MARK: Actions
    @IBAction func showSections(sender:AnyObject?) {
        let ver:NSString = UIDevice.currentDevice().systemVersion as NSString
        let majorVersion = ver.componentsSeparatedByString(".")[0] as String
        if majorVersion.toInt() >= 8 && UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            var alertController = UIAlertController(title: NSLocalizedString("Please select a category", tableName: nil, value: "Please select a category", comment: "ActionSheet title."), message: "", preferredStyle: .Alert)
            for key in categories.keys {
                let action = UIAlertAction(title: key, style: .Default, handler: { [weak self] (act) in
                    var strongSelf = self!
                    strongSelf.title = key
                    strongSelf.loadFirstPageForKey(key)
                })
                alertController.addAction(action)
            }
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", tableName: nil, value: "Cancel", comment: "Cancel button. (General)"), style: .Default) { [weak self] (action) in
                self!.dismissViewControllerAnimated(true, completion: nil)
            }
            alertController.addAction(cancelAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        else {
            var sheet = UIActionSheet(title: NSLocalizedString("Please select a category", tableName: nil, value: "Please select a category", comment: "ActionSheet title."), delegate: self, cancelButtonTitle: NSLocalizedString("Cancel", tableName: nil, value: "Cancel", comment: "Cancel button. (General)"), destructiveButtonTitle: nil)
            for key in categories.keys {
                sheet.addButtonWithTitle(key)
            }
            sheet.showInView(navigationController.view)
        }
    }
    
    @IBAction func refresh(sender:AnyObject?) {
        let key = title
        loadFirstPageForKey(key)
    }
    
    // MARK: Helper
    func loadFirstPageForKey(key:String) {
        forumID = categories[key]!
        posts = []
        page = 1
        tableView.reloadData()
        loatPostListForPage(page)
    }
    
    // MARK: ActionSheet Delegates
    func actionSheet(actionSheet: UIActionSheet!, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex != actionSheet.cancelButtonIndex {
            let key = actionSheet.buttonTitleAtIndex(buttonIndex)
            title = key
            loadFirstPageForKey(key)
        }
    }
}

