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

//swiftlint:disable force_try
class ReceiptParsingTests: XCTestCase {
    var receiptValidator = ReceiptValidator()

    func testFailedReceiptParsing() {
        guard let data = assertTestAsset(filename: "not_a_receipt") else {
            return
        }
        let result = receiptValidator.validateReceipt(origin: .data(data), parameters: .skippingAllValidation)
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
        let result = receiptValidator.validateReceipt(origin: .data(data), parameters: .allValidationsExceptHash)
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
        let result = receiptValidator.validateReceipt(origin: .data(data), parameters: .allValidations)
        guard let receipt = result.receipt else {
            XCTFail("Unexpectedly failed parsing a receipt \(result.error!)")
            return
        }
        print(receipt)
    }
}
