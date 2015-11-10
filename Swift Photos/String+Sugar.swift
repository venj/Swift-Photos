//
//  String+Sugar.swift
//  Swift Photos
//
//  Created by 朱文杰 on 15/11/10.
//  Copyright © 2015年 Venj Chu. All rights reserved.
//

import Foundation

extension String {
    func strip() -> String {
        return self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }

    func split(separator: String) -> [String] {
        return self.componentsSeparatedByString(separator)
    }

    func split(byCharacterSet set: NSCharacterSet) -> [String] {
        return self.componentsSeparatedByCharactersInSet(set)
    }
}