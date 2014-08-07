//
//  Post.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit

class Post: NSObject {
    var title:String!
    var link:String!
    
    init(title:String, link:String) {
        super.init()
        self.title = title
        self.link = link
    }
}
