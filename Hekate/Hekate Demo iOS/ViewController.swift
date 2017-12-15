//
//  ViewController.swift
//  Demo iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Hekate
import UIKit


class ViewController: UIViewController, UITextViewDelegate {

    @IBOutlet private var inputTextView: UITextView!
    @IBOutlet private var outputTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputTextView.delegate = self as UITextViewDelegate
        self.inputTextView.text = ""
        self.outputTextView.text = "Parsed Receipt will be shown here"
        NotificationCenter.default.addObserver(self, selector: #selector(triggerAutoPaste), name: .UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerAutoPaste), name: .UIPasteboardChanged, object: nil)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if autoPaste() {
            return
        } else {
            self.inputTextView.becomeFirstResponder()
        }
    }

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

    @discardableResult
    /// pastes from clipboard if it is base64 decodable
    func autoPaste() -> Bool {
        guard let string = UIPasteboard.general.string,
            Data(base64Encoded: string, options: .ignoreUnknownCharacters) != nil else { return false }

        self.inputTextView.text = string
        self.update(base64String: string)
        return true
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        DispatchQueue.main.async {
            self.update(base64String: self.inputTextView.text)
        }
        return true
    }
}

private extension ViewController {

    func update(base64String: String) {
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            self.render(string: "Base64 decoding failed.")
            return
        }
        do {
            let result = try LocalReceiptValidator().parseUnofficialReceipt(origin: .data(data))
            render(string: "\(result.receipt)\n\(result.unofficialReceipt)")
        } catch {
            self.render(string: "\(error)")
        }
    }

    func render(string: String) {
        self.outputTextView.text = string
    }
}
