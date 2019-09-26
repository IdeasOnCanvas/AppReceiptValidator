//
//  AppReceiptValidationInAppPurchaseTests.swift
//  AppReceiptValidator
//
//  Created by Hannes Oud on 11.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import XCTest

class AppReceiptValidationInAppPurchaseTests: XCTestCase {

    var receiptValidator = AppReceiptValidator()

    func testBearInitialSubscriptionReceiptParsing() {
        guard let data = assertTestAsset(filename: "hannes_bear_introductory_1_week_trial_receipt") else { return }

        // A monthly subscription to Bear on macOS with 2 week introductory offer (free trial) just started.
        let expected = Receipt(
            bundleIdentifier: "net.shinyfrog.bear",
            bundleIdData: "DBJuZXQuc2hpbnlmcm9nLmJlYXI=",
            appVersion: "1.7.3",
            opaqueValue: "9MIfR4OoEFSOXc1fQ1ryDA==",
            sha1Hash: "fgStBECp2Yi0PONokIjcbBpnhvM=",
            originalAppVersion: "1.7.3",
            receiptCreationDate: "2019-09-26T14:08:37Z",
            expirationDate: nil,
            inAppPurchaseReceipts: [
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "net.shinyfrog.bear.pro_monthly_subscription",
                    transactionIdentifier: "240000651265628",
                    originalTransactionIdentifier: "240000651265628",
                    purchaseDate: "2019-09-26T14:08:36Z",
                    originalPurchaseDate: "2019-09-26T14:08:36Z",
                    subscriptionExpirationDate: "2019-10-03T14:08:36Z",
                    cancellationDate: nil,
                    webOrderLineItemId: 240000225193522,
                    isInIntroductoryPricePeriod: false // should this not be true?
                )
            ]
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.shouldValidateHash = false // the original device identifier is unknown
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }

        XCTAssertEqual(receipt, expected)
    }

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
            $0.signatureValidation = .skip
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
                    quantity: 1,
                    productIdentifier: "consumable",
                    transactionIdentifier: "1000000166865231",
                    originalTransactionIdentifier: "1000000166865231",
                    purchaseDate: Date.demoDate(string: "2015-08-07T20:37:55Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-07T20:37:55Z"),
                    subscriptionExpirationDate: nil,
                    cancellationDate: nil,
                    webOrderLineItemId: 0,
                    isInIntroductoryPricePeriod: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166965150",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T06:49:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T06:49:33Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T06:54:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: 1000000030274153,
                    isInIntroductoryPricePeriod: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166965327",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T06:54:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T06:53:18Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T06:59:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: 1000000030274154,
                    isInIntroductoryPricePeriod: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166965895",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T06:59:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T06:57:34Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:04:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: 1000000030274165,
                    isInIntroductoryPricePeriod: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166967152",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T07:04:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T07:02:33Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:09:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: 1000000030274192,
                    isInIntroductoryPricePeriod: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166967484",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T07:09:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T07:08:30Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:14:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: 1000000030274219,
                    isInIntroductoryPricePeriod: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "monthly",
                    transactionIdentifier: "1000000166967782",
                    originalTransactionIdentifier: "1000000166965150",
                    purchaseDate: Date.demoDate(string: "2015-08-10T07:14:32Z"),
                    originalPurchaseDate: Date.demoDate(string: "2015-08-10T07:12:34Z"),
                    subscriptionExpirationDate: Date.demoDate(string: "2015-08-10T07:19:32Z"),
                    cancellationDate: nil,
                    webOrderLineItemId: 1000000030274249,
                    isInIntroductoryPricePeriod: nil
                )
            ]
        )
    }
}
