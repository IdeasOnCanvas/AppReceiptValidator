//
//  UnofficialReceipt.swift
//  Hekate
//
//  Created by Hannes Oud on 15.12.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

/// This collects unofficial ASN1 values

public struct UnofficialReceipt {

    public internal(set) var entries: [Entry]

    public struct Entry {

        public enum Value {
            case string(String)
            case date(Date)
            case bytes(Data)
        }

        public internal(set) var attributeNumber: Int32
        public internal(set) var meaning: KnownUnofficialReceiptAttribute?
        public internal(set) var value: Value?
    }
}

public enum KnownUnofficialReceiptAttribute: Int32 {

    case provisioningType = 0 // String, probably Provisioning-Type, Encountered Values: "Production", "ProductionSandbox"
    case date1 = 8 // some date, same as receiptCreationDate possibly
    case ageRating = 10 // String, probably Age Description, example Value "4+"
    case date2 = 18 // some date, same as receiptCreationDate possibly
    case date3 = 22 // some date, same as receiptCreationDate possibly
    case clientName = 23 // String, probably VPP client name
    // - and of unknown type 14(L=3), 25(L=3), 11(L=4), 13(L=4), 1(L=6), 9(L=6), 16(L=6), 15(L=8), 7(L=66), 6(L=69 variable)

    enum ParsingType {
        case string
        case date
        case data
    }

    var parsingType: ParsingType {
        switch self {
        case .date1, .date2, .date3:
            return .string
        case .provisioningType, .ageRating, .clientName:
            return .string
        }
    }
}

extension UnofficialReceipt: CustomStringConvertible {

    public var description: String {
        return "UnofficialReceipt([\n" + (entries.sorted(by: <).map { "    \($0)" }.joined(separator: ",\n" )) + "\n])"
    }
}

extension UnofficialReceipt.Entry {

    public static func < (lhs: UnofficialReceipt.Entry, rhs: UnofficialReceipt.Entry) -> Bool {
        if lhs.meaning != nil && rhs.meaning == nil {
            return true
        }
        if lhs.meaning == nil && rhs.meaning != nil {
            return false
        }
        return lhs.attributeNumber < rhs.attributeNumber
    }
}

extension UnofficialReceipt.Entry: CustomStringConvertible {

    public var description: String {
        switch self.meaning {
        case .some(let attribute):
            return "\(attributeNumber)\t = \(attribute): \(formatValue(value))"
        case .none:
            return "\(attributeNumber)\t = unknown: \(formatValue(value))"
        }
    }

    private func formatValue(_ value: Value?, fallback: String = "" ) -> String {
        guard let value = value else {
            return fallback
        }
        return value.description
    }
}

extension UnofficialReceipt.Entry.Value: CustomStringConvertible {

    public var description: String {
        switch self {

        case .string(let value):
            return "\"\(value)\""
        case .date(let date):
            return LocalReceiptValidator.asn1DateFormatter.string(from: date)
        case .bytes(let bytes):
            if bytes.count == 2 && bytes.first == 12 && bytes.dropFirst().first == 0 {
                return "2 bytes (12, 0)"
            }
            if bytes.isEmpty {
                return "0 bytes"
            }
            if let utf8 = String(bytes: bytes, encoding: .utf8) {
                return "utf8: \"\(utf8)\""
            }
            return "len: \(bytes.count), b64: \(bytes.base64EncodedString())"
        }
    }
}
