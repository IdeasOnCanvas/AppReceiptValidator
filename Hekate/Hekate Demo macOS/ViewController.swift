//
//  ViewController.swift
//  Hekate Demo macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Cocoa
import Hekate


// MARK: - ViewController

class ViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet private var inputTextView: NSTextView!
    @IBOutlet private var outputTextView: NSTextView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputTextView.delegate = self
        self.inputTextView.string = "Paste Base64 here"
        self.outputTextView.string = "Parsed Receipt will be shown here"
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        let string = inputTextView.string
        self.update(base64String: string)
    }

    // MARK: - Actions

    func paste(_ sender: Any) {
        self.inputTextView.paste(sender)
    }
}

// MARK: - Private

private extension ViewController {

    // MARK: Updating
    func update(base64String: String) {
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            self.render(string: "Base64 decoding failed.")
            return
        }
        do {
            let result = try LocalReceiptValidator().parseUnofficialReceipt(origin: .data(data))
            self.render(string: "\(result.receipt)\n\(result.unofficialReceipt)")
        } catch {
            self.render(string: "\(error)")
        }
    }

    func render(string: String) {
        self.outputTextView.string = string
    }
}

// MARK: - TextView

/// TextView that clears contents before pasting
private class TextView: NSTextView {

    override func paste(_ sender: Any?) {
        self.string = ""
        super.paste(sender)
    }
}
