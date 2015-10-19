//
//  Post.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

class Post {
    var title:String!
    var link:String!
    var progress:Float = 0
    var imageCached:Bool {
        get {
            return imagesCached(forPostLink:link)
        }
    }
    
    init(title:String, link:String) {
        self.title = title
        self.link = link
    }
}
