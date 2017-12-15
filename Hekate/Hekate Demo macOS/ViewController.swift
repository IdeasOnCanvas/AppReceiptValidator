//
//  ViewController.swift
//  Hekate Demo macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Cocoa
import Hekate


class ViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet private var inputTextView: NSTextView!
    @IBOutlet private var outputTextView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        inputTextView.delegate = self
        inputTextView.string = "Paste Base64 here"
        outputTextView.string = "Parsed Receipt will be shown here"
    }

    func textDidChange(_ notification: Notification) {
        let string = inputTextView.string
        update(base64String: string)
    }

    func paste(_ sender: Any) {
        inputTextView.paste(sender)
    }
}

class TextView: NSTextView {

    override func paste(_ sender: Any?) {
        self.string = ""
        super.paste(sender)
    }
}

private extension ViewController {

    func update(base64String: String) {
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            render(string: "Base64 decoding failed.")
            return
        }
        do {
//            let receipt = try LocalReceiptValidator().parseReceipt(origin: .data(data))
            let result = try LocalReceiptValidator().parseUnofficialReceipt(origin: .data(data))
            render(string: "\(result.receipt)\n\(result.unofficialReceipt)")
        } catch {
            render(string: "\(error)")
        }
    }

    func render(string: String) {
        outputTextView.string = string
    }
}
