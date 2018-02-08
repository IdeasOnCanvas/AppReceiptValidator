//
//  LocalReceiptValidationInAppPurchaseTests.swift
//  AppReceiptValidator
//
//  Created by Hannes Oud on 11.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import XCTest

class LocalReceiptValidationInAppPurchaseTests: XCTestCase {

    var receiptValidator = LocalReceiptValidator()

    func testNonMindNodeReceiptParsingWithoutValidation() {
        guard let data = assertB64TestAsset(filename: "grandUnifiedExpiredAppleCert_receipt.b64") else { return }

        do {
            let receipt = try receiptValidator.parseReceipt(origin: .data(data))
            XCTAssertEqual(receipt, nonMindNodeReceipt)
        } catch {
            XCTFail("Unexpectedly failed parsing a receipt \(error)")
        }

    }

    func testNonMindNodeReceiptParsingWithMultipleInAppPurchases() {
        // From https://stackoverflow.com/questions/33843281/apple-receipt-data-sample "Grand Unified Receipt (multiple transactions)"
        // note that the "deprecated transaction (single transaction) style receipt" from the same page doesn't work (base64 problem?)
        guard let data = assertB64TestAsset(filename: "grandUnifiedExpiredAppleCert_receipt.b64") else { return }

        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.shouldValidateHash = false
            $0.shouldValidateSignatureAuthenticity = false
            $0.propertyValidations = []
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        XCTAssertEqual(receipt, nonMindNodeReceipt)
    }

    private var nonMindNodeReceipt: Receipt {
        return Receipt(
            bundleIdentifier: "com.mbaasy.ios.demo",
            bundleIdData: Data(base64Encoded: "DBNjb20ubWJhYXN5Lmlvcy5kZW1v"),
            appVersion: "1",
            opaqueValue: Data(base64Encoded: "xN1AVLC2Gge+tYX2qELgSA=="),
            sha1Hash: Data(base64Encoded: "LgoRW+rBxXAjpb03NJlVqa2Z200="),
            originalAppVersion: "1.0",
            receiptCreationDate: Date.demoDate(string: "2015-08-13T07:50:46Z"),
            expirationDate: nil,
            inAppPurchaseReceipts: [
                InAppPurchaseReceipt(
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
                InAppPurchaseReceipt(
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
                InAppPurchaseReceipt( // restores
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
                InAppPurchaseReceipt(
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
                InAppPurchaseReceipt(
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
                InAppPurchaseReceipt(
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
                InAppPurchaseReceipt(
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
    }
}
