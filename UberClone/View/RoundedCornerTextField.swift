//
//  RoundedTextField.swift
//  UberClone
//
//  Created by Peter Bassem on 3/26/19.
//  Copyright © 2019 Peter Bassem. All rights reserved.
//

import UIKit

class RoundedCornerTextField: UITextField {
    
    var textRectOffset: CGFloat = 20
    var padding: UIEdgeInsets!
    
    override func awakeFromNib() {
        setupView()
        padding  = UIEdgeInsets(top: 0 + textRectOffset, left: textRectOffset, bottom: 0 + (textRectOffset / 2), right: textRectOffset)
    }

    func setupView() {
        self.layer.cornerRadius = self.frame.height / 2
        self.clipsToBounds = true
    }
    
    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}
