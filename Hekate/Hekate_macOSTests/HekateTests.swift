//
//  HekateTests.swift
//  Hekate_macOSTests
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Hekate
import XCTest

//swiftlint:disable force_try
class HekateTests: XCTestCase {
    func testDecodePayloadFromContainerSuccess() {
        _ = assertDecodePayload(filename: "hannes_mac_mindnode_receipt")
        _ = assertDecodePayload(filename: "hannes_mac_mindnode_pro_receipt")
    }

    func testDecodePayloadFromContainerFailure() {
        guard let error = assertDecodePayloadFailure(filename: "not_a_receipt") else {
            return
        }
        guard let hekateError = error as? HekateError else {
            XCTFail("Unexpected error type \(error)")
            return
        }
        XCTAssertEqual(hekateError, HekateError.failedToUpdateCMSDecoder)
    }
}


extension XCTestCase {
    func assertDecodePayload(filename: String, file: StaticString = #file, line: UInt = #line) -> Data? {
        guard let data = assertTestAsset(filename: filename) else { return nil }
        do {
            let decoded = try Hekate.decodeASN1Payload(receiptPKCS7ContainerData: data)
            XCTAssertNotNil(decoded)
            if decoded.isEmpty {
                XCTFail("Found empty Payload", file: file, line: line)
            }
            return decoded
        } catch {
            XCTFail("Error when decoding payload from receipt container: \(error)", file: file, line: line)
            return nil
        }
    }

    func assertDecodePayloadFailure(filename: String, file: StaticString = #file, line: UInt = #line) -> Error? {
        guard let data = assertTestAsset(filename: filename) else { return nil }
        do {
            let decoded = try Hekate.decodeASN1Payload(receiptPKCS7ContainerData: data)
            XCTFail("Expected error decoding the palyoad, but found none, instead found decoded data \(decoded)", file: file, line: line)
            return nil
        } catch {
            return error
        }
    }
}
