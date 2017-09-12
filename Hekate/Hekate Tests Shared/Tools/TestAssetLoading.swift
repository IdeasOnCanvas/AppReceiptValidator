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

    func assertB64TestAsset(filename: String, file: StaticString = #file, line: UInt = #line) -> Data? {

        guard let data = assertTestAsset(filename: filename, file: file, line: line) else {
            return nil
        }
        guard let decoded = Data(base64Encoded: data, options: Data.Base64DecodingOptions.ignoreUnknownCharacters)  else {
            XCTFail("Failed to decode base64 of test asset file \(filename)", file: file, line: line)
            return nil
        }
        return decoded
    }

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
    guard let path = Bundle(for: type(of: requester)).path(forResource: filename, ofType: nil),
        let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        throw TestAssetLoadingError.fileNotReadable(filename: filename)
    }

    return data
}

enum TestAssetLoadingError: Error {

    case fileNotReadable(filename: String)
}
