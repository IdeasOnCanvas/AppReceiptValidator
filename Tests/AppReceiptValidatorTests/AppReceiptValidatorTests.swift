//
//  AppReceiptValidatorTests.swift
//  AppReceiptValidator_macOSTests
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import XCTest

class AppReceiptValidatorTests: XCTestCase {

    private let receiptValidator = AppReceiptValidator()

    private let exampleDeviceIdentifier = AppReceiptValidator.Parameters.DeviceIdentifier(base64Encoded: "bEAItZRe")!

    func testFailedReceiptValidating() {
        guard let data = assertTestAsset(filename: "not_a_receipt") else { return }

        let result = receiptValidator.validateReceipt(configuration: {
            $0.receiptOrigin = .data(data)
        })

        guard let error = result.error else {
            XCTFail("Unexpectedly succeeded in parsing a non-receipt")
            return
        }

        if error != AppReceiptValidator.Error.emptyReceiptContents {
            XCTFail("Unexpected error, expected .emptyReceiptContents, got \(error)")
        }
    }

    func testFailedReceiptParsing() {
        guard let data = assertTestAsset(filename: "not_a_receipt") else { return }

        do {
            _ = try receiptValidator.parseReceipt(origin: .data(data))
            XCTFail("Unexpectedly succeeded in parsing a non-receipt")
        } catch {
            guard error as? AppReceiptValidator.Error == AppReceiptValidator.Error.emptyReceiptContents else {
                XCTFail("Unexpected error, expeced .emptyReceiptContents, got \(error)")
                return
            }
        }
    }

    func testMindNodeProMacReceiptPropertyValidation() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_2_receipt") else { return }

        let expected = Receipt(
            bundleIdentifier: "com.ideasoncanvas.MindNodeMac",
            bundleIdData: "DB1jb20uaWRlYXNvbmNhbnZhcy5NaW5kTm9kZU1hYw==",
            appVersion: "2.5.8",
            opaqueValue: "ZRyo4rFO+zpyYoGJoDUYIQ==",
            sha1Hash: "EtemZhuYKqGofTIwv+x0nNqS5BU=",
            originalAppVersion: "2.5.5",
            receiptCreationDate: "2023-02-22T12:56:25Z",
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.shouldValidateHash = false // the original device identifier is unknown
            $0.propertyValidations = [ .string(\.appVersion, expected: "2.5.8"),
                                       .string(\.originalAppVersion, expected: "2.5.5")]
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }

        XCTAssertEqual(receipt, expected)
    }

    func testMindNodeProMacReceiptParsing() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_2_receipt") else { return }

        let expected = Receipt(
            bundleIdentifier: "com.ideasoncanvas.MindNodeMac",
            bundleIdData: "DB1jb20uaWRlYXNvbmNhbnZhcy5NaW5kTm9kZU1hYw==",
            appVersion: "2.5.8",
            opaqueValue: "ZRyo4rFO+zpyYoGJoDUYIQ==",
            sha1Hash: "EtemZhuYKqGofTIwv+x0nNqS5BU=",
            originalAppVersion: "2.5.5",
            receiptCreationDate: "2023-02-22T12:56:25Z",
            expirationDate: nil,
            inAppPurchaseReceipts: []
        )
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.shouldValidateHash = false // the original device identifier is unknown
            $0.propertyValidations = [ .string(\.appVersion, expected: "2.5.8"),
                                       .string(\.originalAppVersion, expected: "2.5.5")]
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }

        XCTAssertEqual(receipt, expected)
    }

    func testInvalidRootCertificate() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_2_receipt") else { return }
        guard let notAppleRootCert = assertTestAsset(filename: "frank4dd-cacert.der") else { return } // from https://fm4dd.com/openssl/certexamples.shtm

        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.shouldValidateHash = false // the original device identifier is unknown
            $0.signatureValidation = .shouldValidate(rootCertificateOrigin: .data(notAppleRootCert))
        }

        XCTAssertNotNil(result.error)
    }

    func testCustomerReceiptParsing() throws {
        // "Receipt that was bought by a user recently, after having a refund requested 2 years ago", obtained by Marcus
        guard let data = assertTestAsset(filename: "mac_mindnode_rebought_receipt") else { return }

        // just parsing, not validating because the intermediate Apple certificate with which this receipt was signed has expired in the meantime

        let expected = Receipt(
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

        let receipt = try receiptValidator.parseReceipt(origin: .data(data))
        XCTAssertEqual(receipt, expected)
    }

    func testMindNodeMacReceiptWithExpiredSigningValidation() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else { return }

        let expected = Receipt(
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

        do {
            // regular validation should fail
            let result1 = receiptValidator.validateReceipt {
                $0.receiptOrigin = .data(data)
                $0.deviceIdentifier = AppReceiptValidator.Parameters.DeviceIdentifier(base64Encoded: "bEAItZRe")!
            }
            XCTAssertEqual(result1.error, AppReceiptValidator.Error.certificateChainInvalid)
        }

        do {
            // validation skipping signing should succeed
            let result = receiptValidator.validateReceipt {
                $0.receiptOrigin = .data(data)
                $0.deviceIdentifier = AppReceiptValidator.Parameters.DeviceIdentifier(base64Encoded: "bEAItZRe")!
                $0.signatureValidation = .skip
            }

            guard let receipt = result.receipt else {
                XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
                return
            }

            XCTAssertEqual(receipt, expected)
        }
    }

    func testMindNodeMacReceiptParsingWithoutValidation() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else { return }

        let expected = Receipt(
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
            $0.shouldValidateHash = false
            $0.shouldValidateSignaturePresence = false
            $0.signatureValidation = .skip
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }

        XCTAssertEqual(receipt, expected)
    }

    func testMindNodeMacReceiptParsingWithParseMethod() throws {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else { return }

        let expected = Receipt(
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

        let receipt = try receiptValidator.parseReceipt(origin: .data(data))
        XCTAssertEqual(receipt, expected)
    }

    func testNonMindNodeFailingDeprecatedSinglesTypeExpiredAppleCertParsing() {
        guard let data = assertB64TestAsset(filename: "deprecatedSinglesTypeExpiredAppleCert_receipt.b64") else { return }

        let result = receiptValidator.validateReceipt { (parameters: inout AppReceiptValidator.Parameters) -> Void in
            parameters.receiptOrigin = .data(data)
        }
        guard let error = result.error else {
            XCTFail("Unexpectedly succeeded in parsing a non-receipt")
            return
        }

        if error != AppReceiptValidator.Error.emptyReceiptContents {
            XCTFail("Unexpected error, expeced .emptyReceiptContents, got \(error)")
        }
    }

    func testMindNodeiOSSandBoxReceipt1Parsing() throws {
        guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt1.b64") else { return }

        // just parsing, not validating because the intermediate Apple certificate with which this receipt was signed has expired in the meantime

        let receipt = try receiptValidator.parseReceipt(origin: .data(data))
        let expected = Receipt(
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

        XCTAssertEqual(receipt, expected)
    }

    func testUnofficialProvisioningTypes() throws {
        do {
            guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt1.b64") else { return }

            let result = try receiptValidator.parseUnofficialReceipt(origin: .data(data))
            XCTAssertEqual(result.unofficialReceipt.provisioningType, .known(value: .productionSandbox))
        }
        do {
            guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt2.b64") else { return }

            let result = try receiptValidator.parseUnofficialReceipt(origin: .data(data))
            XCTAssertEqual(result.unofficialReceipt.provisioningType, .known(value: .productionSandbox))
        }
        do {
            guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else { return }

            let result = try receiptValidator.parseUnofficialReceipt(origin: .data(data))
            XCTAssertEqual(result.unofficialReceipt.provisioningType, .known(value: .production))
        }
    }

    func testInAppPurchaseParsingAndValidationWithSandboxReceipt() {
        // this was obtained by making purchases in a DEBUG build of a sample app
        guard let data = assertB64TestAsset(filename: "purchasing_experiments_sandbox_receipt.b64") else { return }

        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.deviceIdentifier = .data(Data(base64Encoded: "5hgQmGLdQz+7lGddOBXSYw==")!)
        }

        let expected = Receipt(
            bundleIdentifier: "com.hannesoid.PurchasingExperiments",
            bundleIdData: "DCNjb20uaGFubmVzb2lkLlB1cmNoYXNpbmdFeHBlcmltZW50cw==",
            appVersion: "1",
            opaqueValue: "CPYuy3sssm2OQks5Dfav1Q==",
            sha1Hash: "gfxUPQjdI7OUJFRcSX7Hl/98JpI=",
            originalAppVersion: "1.0",
            receiptCreationDate: "2023-02-22T14:30:15Z",
            expirationDate: nil,
            inAppPurchaseReceipts: [
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "com.hannesoid.PurchasingExperiments.oneTime",
                    transactionIdentifier: "2000000284164152",
                    originalTransactionIdentifier: "2000000284164152",
                    purchaseDate: "2023-02-22T14:29:20Z",
                    originalPurchaseDate: "2023-02-22T14:29:20Z",
                    subscriptionExpirationDate: nil,
                    cancellationDate: nil,
                    webOrderLineItemId: nil
                ),
                InAppPurchaseReceipt(
                    quantity: 1,
                    productIdentifier: "com.hannesoid.PurchasingExperiments.subscription1",
                    transactionIdentifier: "2000000284164527",
                    originalTransactionIdentifier: "2000000284164527",
                    purchaseDate: "2023-02-22T14:29:39Z",
                    originalPurchaseDate: "2023-02-22T14:29:44Z",
                    subscriptionExpirationDate: "2023-02-22T14:34:39Z",
                    cancellationDate: nil,
                    webOrderLineItemId: 2000000021470597
                )
            ]
        )

        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }

        XCTAssertEqual(receipt, expected)
    }

    func DISABLED_testiOSParsingPerformance() {
        guard let data = assertB64TestAsset(filename: "mindnode_ios_michaelsandbox_receipt1.b64") else { return }

        let parameters = AppReceiptValidator.Parameters.default.with {
            $0.receiptOrigin = .data(data)
            $0.deviceIdentifier = AppReceiptValidator.Parameters.DeviceIdentifier(uuid: UUID(uuidString: "3B76A7BD-8F5B-46A4-BCB1-CCE8DBD1B3CD")!)
        }
        measure {
            _ = receiptValidator.validateReceipt(parameters: parameters)
        }
    }
}

// MARK: - AppReceiptValidator + Convenience

extension AppReceiptValidator {

    /// Validates a receipt and returns the result using the parameters `AppReceiptValidator.Parameters.default`, which can be further configured in the passed block.
    func validateReceipt(configuration: (inout Parameters) -> Void) -> Result {
        return validateReceipt(parameters: Parameters.default.with(block: configuration))
    }
}
