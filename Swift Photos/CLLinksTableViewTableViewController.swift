//
//  CLLinksTableViewTableViewController.swift
//  Swift Photos
//
//  Created by 朱 文杰 on 15/2/28.
//  Copyright (c) 2015年 Venj Chu. All rights reserved.
//

import UIKit

class CLLinksTableViewTableViewController: UITableViewController {
    
    let CLLinksCellIdentifier = "CLLinksReuseIdentifier"

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    var clLinks : [String]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Choose 1024 Link", comment: "选择草榴网址")
        tableView.registerClass(NSClassFromString("UITableViewCell"), forCellReuseIdentifier: CLLinksCellIdentifier)

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
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return clLinks.count
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(CLLinksCellIdentifier, forIndexPath: indexPath) 
        
        let clLink = clLinks[indexPath.row]
        cell.textLabel!.text = clLink
        let currentCLLink = getValue(CurrentCLLinkKey) as! NSString?
        
        if let l = currentCLLink {
            if l.isEqualToString(clLink) {
                cell.accessoryType = .Checkmark
            }
            else {
                cell.accessoryType = .None
            }
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let count = clLinks.count
        for var i = 0; i < count; i++ {
            //let ip = NSIndexPath(forRow: i, inSection: 0);
            let cell = tableView.cellForRowAtIndexPath(indexPath)
            if indexPath.row == i {
                cell?.accessoryType = .Checkmark
            }
            else {
                cell?.accessoryType = .None
            }
        }
        tableView.reloadData()
        saveValue(clLinks[indexPath.row], forKey: CurrentCLLinkKey)
    }
}
