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
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func split(_ separator: String) -> [String] {
        return components(separatedBy: separator)
    }

    func split(byCharacterSet set: CharacterSet) -> [String] {
        return components(separatedBy: set)
    }
}
