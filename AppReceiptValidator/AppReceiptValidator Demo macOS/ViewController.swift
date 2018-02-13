//
//  ViewController.swift
//  AppReceiptValidator Demo macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import Cocoa


// MARK: - ViewController

class ViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet private var inputTextView: NSTextView!
    @IBOutlet private var outputTextView: NSTextView!
    @IBOutlet private var dropReceivingView: DropAcceptingTextView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputTextView.delegate = self
        self.inputTextView.string = "Drag Application or receipt here, or paste Base64 receipt contents."
        self.outputTextView.string = "Parsed Receipt will be shown here"
        self.dropReceivingView.handleDroppedFile = { [unowned self] url in
            self.update(url: url)
        }
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
            let result = try AppReceiptValidator().parseUnofficialReceipt(origin: .data(data))
            self.render(string: "\(result.receipt)\n\(result.unofficialReceipt)")
        } catch {
            self.render(string: "\(error)")
        }
    }

    func update(url: URL) {
        var url = url
        let subURLInApplication = url.appendingPathComponent("Contents/_MASReceipt/receipt")
        if FileManager.default.fileExists(atPath: subURLInApplication.path) {
            url = subURLInApplication
        }
        if let data = try? Data(contentsOf: url) {
            let base64 = data.base64EncodedString()
            self.inputTextView.string = base64
            self.update(base64String: base64)
        } else {
            self.inputTextView.string = "<No Receipt found>"
            self.update(base64String: "")
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
