//
//  AppReceiptPropertyValidationTests.swift
//  AppReceiptValidator iOS
//
//  Created by Hannes Oud on 14.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import XCTest

class AppReceiptPropertyValidationTests: XCTestCase {

    private let receiptValidator = AppReceiptValidator()

    #if !os(Linux)
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
                .bundleIdMatchingMainBundle,
                .appVersionMatchingMainBundleIOS
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
                .bundleIdMatchingMainBundle,
                .appVersionMatchingMainBundleMacOS
                ])
        } catch {
            XCTFail("validation failed unexpectedly")
        }
    }
    #endif

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
                .string(\Receipt.bundleIdentifier, expected: "bundleIdentifier"),
                .string(\Receipt.appVersion, expected: "appVersion"),
                .string(\Receipt.originalAppVersion, expected: "originalAppVersion")
                ])
        } catch {
            XCTFail("validation failed unexpectedly")
        }
    }

    func testMindNodeProMacReceiptPropertyMismatches() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_2_receipt") else { return }

        @discardableResult
        func assertPropertyMismatch(line: UInt = #line, configuration: (inout AppReceiptValidator.Parameters) -> Void) -> Bool {
            let result = receiptValidator.validateReceipt {
                $0.receiptOrigin = .data(data)
                $0.shouldValidateHash = false // the original device identifier is unknown
                $0.propertyValidations = [ .string(\.appVersion, expected: "mismatching property"),
                                           .string(\.originalAppVersion, expected: "1.10.6")]
            }
            guard let error = result.error else {
                XCTFail("Unexpectedly succeeded validating, but expected a property mismatch)", file: #file, line: line)
                return false
            }
            guard error == AppReceiptValidator.Error.propertyValueMismatch else {
                XCTFail("Expected a property mismatch, but found an \(error)", file: #file, line: line)
                return false
            }

            return true
        }

        assertPropertyMismatch {
            $0.propertyValidations = [.string(\.appVersion, expected: "mismatching property"),
                                      .string(\.originalAppVersion, expected: "1.10.6")]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [.string(\.appVersion, expected: "1.11.5"),
                                      .string(\.originalAppVersion, expected: "mismatching property")]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [.string(\.bundleIdentifier, expected: "mismatching property")]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [.string(\.bundleIdentifier, expected: "mismatching property"),
                                      .string(\.appVersion, expected: "mismatching property") ]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [.string(\.bundleIdentifier, expected: "mismatching property"),
                                      .string(\.appVersion, expected: "mismatching property") ]
        }
        #if !os(Linux)
        assertPropertyMismatch {
            $0.propertyValidations = [.bundleIdMatchingMainBundle]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [.appVersionMatchingMainBundleIOS]
        }
        assertPropertyMismatch {
            $0.propertyValidations = [.appVersionMatchingMainBundleMacOS]
        }
        #endif
    }
}
