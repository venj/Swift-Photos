//
//  Helpers.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/8.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit

func showHUDInView(view:UIView, withMessage message: String, afterDelay delay:NSTimeInterval) -> MBProgressHUD {
    var messageHUD = MBProgressHUD.showHUDAddedTo(view, animated: true)
    messageHUD.mode = MBProgressHUDModeCustomView
    messageHUD.labelText = message
    if delay != 0.0 {
        messageHUD.hide(true, afterDelay: delay)
    }
    return messageHUD
}
