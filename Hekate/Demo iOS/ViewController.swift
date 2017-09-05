//
//  ViewController.swift
//  Demo iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Hekate_iOS
import UIKit

class ViewController: UIViewController {
    @IBOutlet private weak var label: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        let someClass = SomeClass()
        label?.text = someClass.someString()
    }
}
