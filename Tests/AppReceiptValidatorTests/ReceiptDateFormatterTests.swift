//
//  ReceiptDateFormatterTests.swift
//  AppReceiptValidator
//
//  Created by Hannes Oud on 09.10.20.
//  Copyright © 2020 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator
import Foundation
import XCTest


final class ReceiptDateFormatterTests: XCTestCase {

    func testDateFormatting() throws {
        let dateStrings = [
            "2020-01-01T12:00:00Z",
            "2020-01-01T12:00:00.123Z",
            "2020-01-01T12:00:00.999Z",
            "2020-01-01T12:00:01Z"
        ]
        for dateString in dateStrings {
            let parsed = try XCTUnwrap(AppReceiptValidator.ReceiptDateFormatter.date(from: dateString))
            XCTAssertEqual(AppReceiptValidator.ReceiptDateFormatter.string(from: parsed), dateString)
        }
    }
}
