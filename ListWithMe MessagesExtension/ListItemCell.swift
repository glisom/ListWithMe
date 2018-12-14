//
//  ListItemCell.swift
//  ListWithMe MessagesExtension
//
//  Created by Isom,Grant on 12/7/18.
//  Copyright © 2018 Grant Isom. All rights reserved.
//

import UIKit

class ListItemCell: UITableViewCell {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var mainView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        mainView.layer.cornerRadius = 10.0
        textField.autocapitalizationType = .sentences
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
