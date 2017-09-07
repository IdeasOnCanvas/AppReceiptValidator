//
//  HekateTests.swift
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

class ReceiptParsingTests: XCTestCase {
    var receiptValidator = ReceiptValidator()

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
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.validateHash = false
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
    }

    func testMindNodeMacReceiptParsing() {
        guard let data = assertTestAsset(filename: "hannes_mac_mindnode_receipt") else {
            return
        }
        let result = receiptValidator.validateReceipt {
            $0.receiptOrigin = .data(data)
            $0.deviceIdentifier = ReceiptDeviceIdentifier(base64Encoded: "bEAItZRe")!
        }
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
    }
}
