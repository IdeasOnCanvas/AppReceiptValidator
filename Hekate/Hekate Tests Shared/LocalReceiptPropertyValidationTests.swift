//
//  LocalReceiptPropertyValidationTests.swift
//  Hekate iOS
//
//  Created by Hannes Oud on 14.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Hekate
import XCTest

class LocalReceiptPropertyValidationTests: XCTestCase {

    private let receiptValidator = LocalReceiptValidator()

    func testCorrectMainBundlePropertiesiOS() {
        let receipt = Receipt(bundleIdentifier: Bundle.main.bundleIdentifier,
                              bundleIdData: nil,
                              appVersion: Bundle.main.infoDictionary?[String(kCFBundleVersionKey)] as? String,
                              opaqueValue: nil,
                              sha1Hash: nil,
                              originalAppVersion: nil,
                              receiptCreationDate: nil,
                              expirationDate: nil,
                              inAppPurchaseReceipts: [])
        do {
            try receiptValidator.validateProperties(receipt: receipt, validations: [
                .compareMainBundleIdentifier,
                .compareMainBundleIOSAppVersion
            ])
        } catch {
            XCTFail("validation failed unexpectedly")

        }
    }

    func testCorrectMainBundlePropertiesMacOS() {
        let receipt = Receipt(bundleIdentifier: Bundle.main.bundleIdentifier,
                              bundleIdData: nil,
                              appVersion: Bundle.main.infoDictionary?[String("CFBundleShortVersionString")] as? String,
                              opaqueValue: nil,
                              sha1Hash: nil,
                              originalAppVersion: nil,
                              receiptCreationDate: nil,
                              expirationDate: nil,
                              inAppPurchaseReceipts: [])
        do {
            try receiptValidator.validateProperties(receipt: receipt, validations: [
                .compareMainBundleIdentifier,
                .compareMainBundleMacOSAppVersion
                ])
        } catch {
            XCTFail("validation failed unexpectedly")

        }
    }

    func testSpecificHardcodedPropertyMatches() {
        let receipt = Receipt(bundleIdentifier: "bundleIdentifier",
                              bundleIdData: nil,
                              appVersion: "appVersion",
                              opaqueValue: nil,
                              sha1Hash: nil,
                              originalAppVersion: "originalAppVersion",
                              receiptCreationDate: nil,
                              expirationDate: nil,
                              inAppPurchaseReceipts: [])
        do {
            try receiptValidator.validateProperties(receipt: receipt, validations: [
                .compareWithValue(receiptProperty: \Receipt.bundleIdentifier, value: "bundleIdentifier"),
                .compareWithValue(receiptProperty: \Receipt.appVersion, value: "appVersion"),
                .compareWithValue(receiptProperty: \Receipt.originalAppVersion, value: "originalAppVersion")
                ])
        } catch {
            XCTFail("validation failed unexpectedly")
        }
    }

    func testMindNodeProMacReceiptPropertyMismatches() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_pro_receipt") else { return }

        @discardableResult
        func assertPropertyMismatch(line: UInt = #line, configuration: (inout LocalReceiptValidator.Parameters) -> Void) -> Bool {
            let result = receiptValidator.validateReceipt {
                $0.receiptOrigin = .data(data)
                $0.shouldValidateHash = false // the original device identifier is unknown
                $0.propertyValidations = [ .compareWithValue(receiptProperty: \.appVersion, value: "mismatching property"),
                                           .compareWithValue(receiptProperty: \.originalAppVersion, value: "1.10.6")]
            }
            guard let error = result.error else {
                XCTFail("Unexpectedly succeeded validating, but expected a property mismatch)", file: #file, line: line)
                return false
            }
            guard error == LocalReceiptValidator.Error.propertyValueMismatch else {
                XCTFail("Expected a property mismatch, but found an \(error)", file: #file, line: line)
                return false
            }

            return true
        }

        assertPropertyMismatch {
            $0.propertyValidations = [ .compareWithValue(receiptProperty: \.appVersion, value: "mismatching property"),
                                       .compareWithValue(receiptProperty: \.originalAppVersion, value: "1.10.6")]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareWithValue(receiptProperty: \.appVersion, value: "1.11.5"),
                                       .compareWithValue(receiptProperty: \.originalAppVersion, value: "mismatching property")]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareWithValue(receiptProperty: \.bundleIdentifier, value: "mismatching property") ]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareWithValue(receiptProperty: \.bundleIdentifier, value: "mismatching property"),
                                       .compareWithValue(receiptProperty: \.appVersion, value: "mismatching property") ]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareWithValue(receiptProperty: \.bundleIdentifier, value: "mismatching property"),
                                       .compareWithValue(receiptProperty: \.appVersion, value: "mismatching property") ]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareMainBundleIdentifier ]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareMainBundleIOSAppVersion ]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [ .compareMainBundleMacOSAppVersion ]
        }
    }
}
