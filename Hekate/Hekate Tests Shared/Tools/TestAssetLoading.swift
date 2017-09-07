//
//  TestAssetLoading.swift
//  Hekate_macOSTests
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import XCTest

extension XCTestCase {
    func assertTestAsset(filename: String, file: StaticString = #file, line: UInt = #line) -> Data? {
        do {
            return try loadTestAsset(filename: filename, requester: self)
        } catch {
            XCTFail("Failed to load test asset file \(filename), make sure you added it to the test target(s)", file: file, line: line)
            return nil
        }
    }
}

private func loadTestAsset(filename: String, requester: AnyObject) throws -> Data {
    if let path = Bundle(for: type(of: requester)).path(forResource: filename, ofType: nil),
        let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
        return data
    }
    throw TestAssetLoadingError.fileNotReadable(filename: filename)
}

enum TestAssetLoadingError: Error {
    case fileNotReadable(filename: String)
}
