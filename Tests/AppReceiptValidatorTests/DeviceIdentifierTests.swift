//
//  DeviceIdentifierTests.swift
//  AppReceiptValidator
//
//  Created by Hannes Oud on 22.11.18.
//  Copyright © 2018 IdeasOnCanvas GmbH. All rights reserved.
//

@testable import AppReceiptValidator
import Foundation
import XCTest

final class DeviceIdentifierTests: XCTestCase {

    func testBase64Initializer() {
        let deviceIdentifier = AppReceiptValidator.Parameters.DeviceIdentifier(base64Encoded: "bEAItZRe")
        XCTAssertNotNil(deviceIdentifier)
    }

    func testMacAddressInitializer() {
        XCTAssertNotNil(AppReceiptValidator.Parameters.DeviceIdentifier(macAddress: "00:0d:3f:cd:02:5f"))
    }

    func testMacAddressInitializerOtherSeparator() {
        XCTAssertNotNil(AppReceiptValidator.Parameters.DeviceIdentifier(macAddress: "00-0d-3f-cd-02-5f", separator: "-"))
    }

    func testUUIDInitializer() {
        XCTAssertNotNil(AppReceiptValidator.Parameters.DeviceIdentifier(uuid: UUID()))
    }

    func testCurrent() {
        let deviceIdentifierData = AppReceiptValidator.Parameters.DeviceIdentifier.currentDevice.getData()
        XCTAssertNotNil(deviceIdentifierData)
    }

    #if os(macOS)
    func testMacAddressRetrieval() {
        guard let (data, string) = AppReceiptValidator.Parameters.DeviceIdentifier.getPrimaryNetworkMACAddress() else {
            XCTFail("Failed to get device mac address")
            return
        }
        guard let deviceIdentifierData = AppReceiptValidator.Parameters.DeviceIdentifier.currentDevice.getData() else {
            XCTFail("Failed to get device mac address")
            return
        }
        XCTAssertEqual(data, deviceIdentifierData)
        guard let deviceIdentifierFromString = AppReceiptValidator.Parameters.DeviceIdentifier(macAddress: string) else {
            XCTFail("Failed to get device identifier from mac address string")
            return
        }
        XCTAssertEqual(deviceIdentifierFromString.getData(), deviceIdentifierData)
    }
    #endif

}
