//
//  KnownOrUnknown.swift
//  Hekate
//
//  Created by Hannes Oud on 08.01.18.
//  Copyright © 2018 IdeasOnCanvas GmbH. All rights reserved.
//

// MARK: - KnownOrUnknown

/// A known or unknown RawRepresentable
///
/// - known: the raw value is known and could be assigned to a known strong value type
/// - unknown: the raw value is unknown and is stored as is
public enum KnownOrUnknown<Known: RawRepresentable> where Known.RawValue: Hashable  {
    public typealias Unknown = Known.RawValue

    case known(value: Known)
    case unknown(rawValue: Unknown)
}

// MARK: - RawRepresentable

extension KnownOrUnknown: RawRepresentable {

    public typealias RawValue = Unknown

    public init?(rawValue: Unknown) {
        if let known = Known(rawValue: rawValue) {
            self = .known(value: known)
        } else {
            self = .unknown(rawValue: rawValue)
        }
    }

    public var rawValue: Unknown {
        switch self {
        case .known(let value):
            return value.rawValue
        case .unknown(let rawValue):
            return rawValue
        }
    }
}

// MARK: - Hashable

extension KnownOrUnknown: Hashable {

    public var hashValue: Int {
        return self.rawValue.hashValue
    }

    public static func ==(lhs: KnownOrUnknown<Known>, rhs: KnownOrUnknown<Known>) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// MARK: - CustomStringConvertible

extension KnownOrUnknown: CustomStringConvertible {

    public var description: String {
        switch self {
        case .known(let value):
            return "\(value)"
        case .unknown(let rawValue):
            return "\"\(rawValue)\""
        }
    }
}
