//
//  ProgressTableViewCell.swift
//  Swift Photos
//
//  Created by 朱 文杰 on 15/7/2.
//  Copyright (c) 2015年 Venj Chu. All rights reserved.
//

import UIKit

class ProgressTableViewCell: UITableViewCell {
    var progress:Float = 0 {
        didSet {
            if progress > 0.0 {
                progressView.alpha = 1.0
            }
            else {
                progressView.alpha = 0.0
            }
            if progress >= 1.0 {
                progressView.tintColor = UIColor.flatGreenColor()
            }
            else {
                progressView.tintColor = UIColor.flatDarkBlueColor()
            }
            progressView.progress = progress
        }
    }
    
    @IBOutlet weak var progressView: UIProgressView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        if progress <= 0.0 {
            progressView.alpha = 0.0;
        }
        else {
            progressView.alpha = 1.0;
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        progress = 0.0;
    }
}
