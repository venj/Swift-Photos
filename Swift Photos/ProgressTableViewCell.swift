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
                self.progressView.alpha = 1.0
            }
            else {
                self.progressView.alpha = 0.0
            }
            if progress >= 1.0 {
                self.progressView.tintColor = UIColor.greenColor()
            }
            else {
                self.progressView.tintColor = nil
            }
            self.progressView.progress = progress
        }
    }
    
    @IBOutlet weak var progressView: UIProgressView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        if self.progress <= 0.0 {
            self.progressView.alpha = 0.0;
        }
        else {
            self.progressView.alpha = 1.0;
        }
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        self.progress = 0.0;
    }
}
