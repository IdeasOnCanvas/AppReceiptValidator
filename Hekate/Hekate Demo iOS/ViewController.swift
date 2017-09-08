//
//  ViewController.swift
//  Demo iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Hekate_iOS
import StoreKit
import UIKit

class ViewController: UIViewController {

    var viewModel = HekateDemoViewModel() {
        didSet {
            self.updateViewFromViewModel()
        }
    }

    @IBOutlet private weak var textView: UITextView!

    @IBOutlet private weak var receiptDataTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.update()
    }

    private func updateViewFromViewModel() {
        textView.text = viewModel.descriptionText
        receiptDataTextView.text = viewModel.receiptDataBase64Text
    }
}
