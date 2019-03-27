//
//  RoundImageView.swift
//  UberClone
//
//  Created by Peter Bassem on 3/25/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit

class RoundImageView: UIImageView {
    
    override func awakeFromNib() {
        setupView()
    }

    func setupView() {
        self.layer.cornerRadius = self.frame.width / 2
        self.clipsToBounds = true
    }
}
