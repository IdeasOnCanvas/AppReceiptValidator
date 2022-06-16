//
//  ViewController.swift
//  AppReceiptValidator Demo macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import Cocoa

/// Displays two textfields. One to paste a receipt into as base64 string, the other displaying the parsed receipt.
/// A device identifier can be added in a third field, which is then used to validate the receipt.
class ViewController: NSViewController, NSTextViewDelegate, NSTextFieldDelegate {

    private var textFieldObserver: Any?
    @IBOutlet private var inputTextView: NSTextView!
    @IBOutlet private var identifierTextField: NSTextField!
    @IBOutlet private var outputTextView: NSTextView!
    @IBOutlet private var dropReceivingView: DropAcceptingTextView!
    @IBOutlet private var localDeviceIdentifierLabel: NSTextField!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputTextView.delegate = self
        self.inputTextView.string = "Drag Application or receipt here, or paste Base64 receipt contents."
        self.outputTextView.string = "Parsed Receipt will be shown here"
        self.dropReceivingView.handleDroppedFile = { [unowned self] url in
            self.update(url: url)
        }
        self.textFieldObserver = NotificationCenter.default.addObserver(forName: NSTextField.textDidChangeNotification, object: self.identifierTextField, queue: .main) { [weak self] _ in
            guard let self = self else { return }

            self.identifierDidChange(self.identifierTextField)
        }
        self.renderLocalDeviceIdentifierText()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        let string = self.inputTextView.string
        self.update(base64String: string)
    }

    // MARK: - Identifier Textfield

    @IBAction func identifierDidChange(_ sender: NSTextField) {
        let string = self.inputTextView.string
        self.update(base64String: string)
    }

    // MARK: - Actions

    func paste(_ sender: Any) {
        self.inputTextView.paste(sender)
    }

    @IBAction func determineDeviceIdentifier(_ sender: Any) {
        self.renderLocalDeviceIdentifierText()
    }
}

// MARK: - Private

private extension ViewController {

    // MARK: Updating

    func update(base64String: String) {
        guard let data = Data(base64Encoded: base64String, options: []) else {
            self.render(string: "Base64 decoding failed.")
            return
        }
        do {
            let result = try AppReceiptValidator().parseUnofficialReceipt(origin: .data(data))
            let validationResult = self.validateReceiptIfNecessary(data: data, macAddress: self.identifierTextField.stringValue) ?? "<Receipt not Validated, No Identifier provided, Supported: UUID, base64, MAC-Address>"
            self.render(string: "\(validationResult)\n\n✅ Receipt Parsed\n\(result.receipt)\n\(result.unofficialReceipt)")
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
            var decodedData: Data {
                if let alreadyEncodedData = Data(base64Encoded: data, options: []) {
                    return alreadyEncodedData
                } else {
                    return data
                }
            }
            let base64 = decodedData.base64EncodedString()
            self.inputTextView.string = base64
            self.update(base64String: base64)
        } else {
            self.inputTextView.string = "<No Receipt found>"
            self.update(base64String: "")
        }
    }

    func validateReceiptIfNecessary(data: Data, macAddress: String?) -> String? {
        guard let macAddress = macAddress, macAddress.isEmpty == false else { return nil }

        let sanitized = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceIdentifier = AppReceiptValidator.Parameters.DeviceIdentifier(macAddress: sanitized) ??
            (UUID(uuidString: sanitized).flatMap { AppReceiptValidator.Parameters.DeviceIdentifier(uuid: $0) }) ??
            AppReceiptValidator.Parameters.DeviceIdentifier(base64Encoded: sanitized)
        guard let identifier = deviceIdentifier else { return "<Receipt not Validated\nIdentifier not parseable>" }

        let parameters = AppReceiptValidator.Parameters(receiptOrigin: .data(data), shouldValidateSignaturePresence: true, signatureValidation: .shouldValidate(rootCertificateOrigin: .cerFileBundledWithAppReceiptValidator), shouldValidateHash: true, deviceIdentifier: identifier, propertyValidations: [])
        let result = AppReceiptValidator().validateReceipt(parameters: parameters)

        switch result {
        case .success:
            return "✅ Receipt Validated\nSignature and Hash Check successful"
        case .error(let error, _, _):
            return "❌ Receipt Invalid\n\(error)"
        }
    }

    func localDeviceIdentifierString() -> String {
        guard let device = AppReceiptValidator.Parameters.DeviceIdentifier.getPrimaryNetworkMACAddress() else { return "DeviceIdentifier could not be determined" }

        return "\(device.addressString) (HEX), \(device.data.base64EncodedString()) (B64)"
    }

    func render(string: String) {
        self.outputTextView.string = string
    }

    func renderLocalDeviceIdentifierText() {
        NSLog("Local MAC Address: " + localDeviceIdentifierString())
        self.localDeviceIdentifierLabel.attributedStringValue =
        NSAttributedString(string: localDeviceIdentifierString())
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
