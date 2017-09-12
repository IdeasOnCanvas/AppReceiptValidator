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
    private let receiptValidator = LocalReceiptValidator()

    private let exampleDeviceIdentifier = ReceiptDeviceIdentifier(base64Encoded: "bEAItZRe")!

    func testFailedReceiptParsing() {
        guard let data = assertTestAsset(filename: "not_a_receipt") else { return }

        let result = receiptValidator.validateReceipt(configuration: {
            $0.receiptOrigin = .data(data)
        })

        guard let error = result.error else {
            XCTFail("Unexpectedly succeeded in parsing a non-receipt")
            return
        }

        if error != ReceiptValidationError.emptyReceiptContents {
            XCTFail("Unexpected error, expected ReceiptValidationError.emptyReceiptContents, got \(error)")
        }
    }

    func testMindNodeProMacReceiptParsing() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_pro_receipt") else { return }

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
        // "Receipt that was bought by a user recently, after having a refund requested 2 years ago", obtained by Marcus
        guard let data = assertTestAsset(filename: "mac_mindnode_rebought_receipt") else { return }

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
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else { return }

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
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else { return }

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

    func testNonMindNodeFailingDeprecatedSinglesTypeExpiredAppleCertParsing() {
        guard let data = assertB64TestAsset(filename: "deprecatedSinglesTypeExpiredAppleCert_receipt.b64") else {
            return
        }
        let result = receiptValidator.validateReceipt { (parameters: inout ReceiptValidationParameters) -> Void in
            parameters.receiptOrigin = .data(data)
        }
        guard let error = result.error else {
            XCTFail("Unexpectedly succeeded in parsing a non-receipt")
            return
        }
        if error != ReceiptValidationError.emptyReceiptContents {
            XCTFail("Unexpected error, expeced ReceiptValidationError.emptyReceiptContents, got \(error)")
        }
    }

    func testMindNodeiOSSandBoxReceipt1ParsingAndValidation() {
        guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt1.b64") else {
            return
        }
        let result = receiptValidator.validateReceipt { (parameters: inout ReceiptValidationParameters) -> Void in
            parameters.receiptOrigin = .data(data)
            parameters.deviceIdentifier = ReceiptDeviceIdentifier(uuid: UUID(uuidString: "3B76A7BD-8F5B-46A4-BCB1-CCE8DBD1B3CD")!)
        }
        let expected = ParsedReceipt(
            bundleIdentifier: "com.mindnode.mindnodetouch",
            bundleIdData: Data(base64Encoded: "DBpjb20ubWluZG5vZGUubWluZG5vZGV0b3VjaA==")!,
            appVersion: "3394",
            opaqueValue: Data(base64Encoded: "YslufpOntElA2SgjZc/BZw=="),
            sha1Hash: Data(base64Encoded: "d3UPNvYmUF8EOyfB9Ap8VBETHbE="),
            originalAppVersion: "1.0",
            receiptCreationDate: Date.demoDate(string: "2017-09-11T09:38:34Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }

        print(receipt)
        XCTAssertEqual(receipt, expected)
    }

    func testMindNodeiOSSandBoxReceipt2ParsingAndValidation() {
        guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt2.b64") else {
            return
        }
        let result = receiptValidator.validateReceipt { (parameters: inout ReceiptValidationParameters) -> Void in
            parameters.receiptOrigin = .data(data)
            parameters.validateHash = false // unknown device identifier
        }
        let expected = ParsedReceipt(
            bundleIdentifier: "com.mindnode.mindnodetouch",
            bundleIdData: Data(base64Encoded: "DBpjb20ubWluZG5vZGUubWluZG5vZGV0b3VjaA==")!,
            appVersion: "3392",
            opaqueValue: Data(base64Encoded: "M10U4Y67k8PYmJdZ0XVfng=="),
            sha1Hash: Data(base64Encoded: "5rkci1hiUWJJ1qHRkRlhrI3Edro="),
            originalAppVersion: "1.0",
            receiptCreationDate: Date.demoDate(string: "2017-08-16T13:13:14Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
        XCTAssertEqual(receipt, expected)
    }


    func testiOSParsingPerformance() {
        guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt1.b64") else {
            return
        }
        let parameters = ReceiptValidationParameters.allSteps.with {
            $0.receiptOrigin = .data(data)
            $0.deviceIdentifier = ReceiptDeviceIdentifier(uuid: UUID(uuidString: "3B76A7BD-8F5B-46A4-BCB1-CCE8DBD1B3CD")!)
        }
        measure {
            _ = receiptValidator.validateReceipt(parameters: parameters)
        }
    }
}
