//
//  ViewController.swift
//  Demo iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import UIKit

/// Displays two textfields. One to paste a receipt into as base64 string, the other displaying the parsed receipt.
/// A device identifier for validation is not supported, have a look at the mac demo instead.
class ViewController: UIViewController, UITextViewDelegate {

    @IBOutlet private var inputTextView: UITextView!
    @IBOutlet private var outputTextView: UITextView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputTextView.delegate = self
        self.inputTextView.text = ""
        self.outputTextView.text = "Parsed Receipt will be shown here"
        NotificationCenter.default.addObserver(self, selector: #selector(triggerAutoPaste), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerAutoPaste), name: UIPasteboard.changedNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.autoPaste() {
            return
        } else {
            self.inputTextView.becomeFirstResponder()
        }
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        DispatchQueue.main.async {
            self.update(base64String: self.inputTextView.text)
        }
        return true
    }
}

// MARK: - Private

private extension ViewController {

    // MARK: Actions

    @objc
    func triggerAutoPaste() {
        self.autoPaste()
    }

    @IBAction func clear() {
        self.inputTextView.text = ""
    }

    @IBAction func copyOutput() {
        UIPasteboard.general.string = self.outputTextView.text
    }

    // MARK: Updating

    /// pastes from clipboard if it is base64 decodable
    @discardableResult
    func autoPaste() -> Bool {
        guard let string = UIPasteboard.general.string,
            Data(base64Encoded: string, options: []) != nil else { return false }

        self.inputTextView.text = string
        self.update(base64String: string)
        return true
    }

    func update(base64String: String) {
        guard let data = Data(base64Encoded: base64String, options: []) else {
            self.render(string: "Base64 decoding failed.")
            return
        }
        do {
            let result = try AppReceiptValidator().parseUnofficialReceipt(origin: .data(data))
            render(string: "\(result.receipt)\n\(result.unofficialReceipt)")
        } catch {
            self.render(string: "\(error)")
        }
    }

    func render(string: String) {
        self.outputTextView.text = string
    }
}
