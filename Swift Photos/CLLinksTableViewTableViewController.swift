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

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    var clLinks : [String] = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Choose 1024 Link", comment: "选择草榴网址")
        tableView.register(NSClassFromString("UITableViewCell"), forCellReuseIdentifier: CLLinksCellIdentifier)

        if #available(iOS 9, *) {
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return clLinks.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CLLinksCellIdentifier, for: indexPath) 
        
        let clLink = clLinks[(indexPath as NSIndexPath).row]
        cell.textLabel!.text = clLink
        let currentCLLink = getValue(CurrentCLLinkKey) as! NSString?
        
        if let l = currentCLLink {
            if l.isEqual(to: clLink) {
                cell.accessoryType = .checkmark
            }
            else {
                cell.accessoryType = .none
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let count = clLinks.count
        for i in 0 ..< count {
            //let ip = NSIndexPath(forRow: i, inSection: 0);
            let cell = tableView.cellForRow(at: indexPath)
            if (indexPath as NSIndexPath).row == i {
                cell?.accessoryType = .checkmark
            }
            else {
                cell?.accessoryType = .none
            }
        }
        tableView.reloadData()
        saveValue(clLinks[(indexPath as NSIndexPath).row], forKey: CurrentCLLinkKey)
    }
}
