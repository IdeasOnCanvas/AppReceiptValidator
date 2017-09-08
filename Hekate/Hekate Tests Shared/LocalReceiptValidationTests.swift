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

    func testNonMindNodeReceiptParsingWithMultipleInAppPurchases() { // swiftlint:disable:this function_body_length
        // from https://stackoverflow.com/questions/33843281/apple-receipt-data-sample "Grand Unified Receipt (multiple transactions)"
        // note that the "deprecated transaction (single transaction) style receipt" from the same page doesn't work (base64 problem?)
        guard let data = assertB64TestAsset(filename: "grandUnifiedExpiredAppleCert_receipt.b64") else {
            return
        }

        let expected = ParsedReceipt(
            bundleIdentifier: "com.mbaasy.ios.demo",
            bundleIdData: Data(base64Encoded: "DBNjb20ubWJhYXN5Lmlvcy5kZW1v"),
            appVersion: "1",
            opaqueValue: Data(base64Encoded: "xN1AVLC2Gge+tYX2qELgSA=="),
            sha1Hash: Data(base64Encoded: "LgoRW+rBxXAjpb03NJlVqa2Z200="),
            originalAppVersion: "1.0",
            receiptCreationDate: Date.demoDate(string: "2015-08-13T07:50:46Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: [
                ParsedInAppPurchaseReceipt(
                    quantity: nil,
                    productIdentifier: "consumable",
                    transactionIdentifier: "1000000166865231",
                    originalTransactionIdentifier: "1000000166865231",
                    purchaseDate: Date.demoDate(string: "2015-08-07T20:37:55Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-07T20:37:55Z"),
                    subscriptionExpirationDate: nil,
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                ParsedInAppPurchaseReceipt(
                    quantity: nil,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166965150",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T06:49:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T06:49:33Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T06:54:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                ParsedInAppPurchaseReceipt( // restores
                    quantity: nil,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166965327",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T06:54:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T06:53:18Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T06:59:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                ParsedInAppPurchaseReceipt(
                    quantity: nil,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166965895",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T06:59:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T06:57:34Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:04:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                ParsedInAppPurchaseReceipt(
                    quantity: nil,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166967152",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T07:04:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T07:02:33Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:09:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                ParsedInAppPurchaseReceipt(
                    quantity: nil,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166967484",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T07:09:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T07:08:30Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:14:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                ParsedInAppPurchaseReceipt(
                    quantity: nil,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166967782",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T07:14:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T07:12:34Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:19:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                )
            ])
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.validateHash = false
            $0.validateSignatureAuthenticity = false
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        XCTAssertEqual(receipt, expected)


        print(receipt)
    }
}
