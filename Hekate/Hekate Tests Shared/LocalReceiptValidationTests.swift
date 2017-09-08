//
//  LocalReceiptValidationTests.swift
//  Hekate_macOSTests
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

#if os(iOS)
import Hekate_iOS
#elseif os(OSX)
import Hekate_macOS
#endif

import XCTest

class LocalReceiptValidationTests: XCTestCase {
    var receiptValidator = LocalReceiptValidator()

    let exampleDeviceIdentifier = ReceiptDeviceIdentifier(base64Encoded: "bEAItZRe")!

    func testFailedReceiptParsing() {
        guard let data = assertTestAsset(filename: "not_a_receipt") else {
            return
        }

        let result = receiptValidator.validateReceipt(configuration: {
            $0.receiptOrigin = .data(data)
        })

        guard let error = result.error else {
            XCTFail("Unexpectedly succeeded in parsing a non-receipt")
            return
        }
        if error != ReceiptValidationError.emptyReceiptContents {
            XCTFail("Unexpected error, expeced ReceiptValidationError.emptyReceiptContents, got \(error)")
        }
    }

    func testMindNodeProMacReceiptParsing() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_pro_receipt") else {
            return
        }
        let expected = ParsedReceipt(
            bundleIdentifier: "com.mindnode.MindNodePro",
            bundleIdData: Data(base64Encoded: "DBhjb20ubWluZG5vZGUuTWluZE5vZGVQcm8=")!,
            appVersion: "1.11.5",
            opaqueValue: Data(base64Encoded: "/cPmDfuyFyluvodJXQRvig=="),
            sha1Hash: Data(base64Encoded: "MDBF4hAt6Y+7IlAydxroa/SQeY4="),
            originalAppVersion: "1.10.6",
            receiptCreationDate: Date.demoDate(string: "2016-02-12T10:57:42Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.validateHash = false // the original device identifier is unknown
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
        XCTAssertEqual(receipt, expected)
    }

    func testCustomerReceiptParsing() {
        // "Receipt von einem User der gestern gekauft hat nachdem er vor 2 Jahren einen Refund von Apple requested hat. Könnte also spannend sein"
        guard let data = assertTestAsset(filename: "mac_mindnode_rebought_receipt") else {
            return
        }
        let expected = ParsedReceipt(
            bundleIdentifier: "com.ideasoncanvas.MindNodeMac",
            bundleIdData: Data(base64Encoded: "DB1jb20uaWRlYXNvbmNhbnZhcy5NaW5kTm9kZU1hYw==")!,
            appVersion: "2.5.5",
            opaqueValue: Data(base64Encoded: "VzgcF3QeYC6RGBfGC5rP+A=="),
            sha1Hash: Data(base64Encoded: "fqauHWwZo7XrxhQJcksK447Fzvg="),
            originalAppVersion: "2.5.5",
            receiptCreationDate: Date.demoDate(string: "2017-09-04T14:45:30Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.validateHash = false // the original device identifier is unknown
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        XCTAssertEqual(receipt, expected)
    }

    func testMindNodeMacReceiptParsingWithFullValidation() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else {
            return
        }
        let expected = ParsedReceipt(
            bundleIdentifier: "com.ideasoncanvas.MindNodeMac",
            bundleIdData: Data(base64Encoded: "DB1jb20uaWRlYXNvbmNhbnZhcy5NaW5kTm9kZU1hYw==")!,
            appVersion: "2.5.5",
            opaqueValue: Data(base64Encoded: "mjF2f4xnFu/L4J3msJ1fxQ=="),
            sha1Hash: Data(base64Encoded: "gfM0Izu/eKMBRLbJqlTXtNvvmss="),
            originalAppVersion: "2.5.5",
            receiptCreationDate: Date.demoDate(string: "2017-09-04T09:01:20Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.deviceIdentifier = ReceiptDeviceIdentifier(base64Encoded: "bEAItZRe")!
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
        XCTAssertEqual(receipt, expected)
    }

    func testMindNodeMacReceiptParsingWithoutValidation() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else {
            return
        }
        let expected = ParsedReceipt(
            bundleIdentifier: "com.ideasoncanvas.MindNodeMac",
            bundleIdData: Data(base64Encoded: "DB1jb20uaWRlYXNvbmNhbnZhcy5NaW5kTm9kZU1hYw==")!,
            appVersion: "2.5.5",
            opaqueValue: Data(base64Encoded: "mjF2f4xnFu/L4J3msJ1fxQ=="),
            sha1Hash: Data(base64Encoded: "gfM0Izu/eKMBRLbJqlTXtNvvmss="),
            originalAppVersion: "2.5.5",
            receiptCreationDate: Date.demoDate(string: "2017-09-04T09:01:20Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.validateHash = false
            $0.validateSignaturePresence = false
            $0.validateSignatureAuthenticity = false
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
        XCTAssertEqual(receipt, expected)
    }
}
