//
//  ASN1Helpers.swift
//  AppReceiptValidator
//
//  Created by Hannes Oud on 07.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import AppReceiptValidator.OpenSSL
import Foundation

/// An ASN1 Sequence Object. Of interest are the attributeType and the valueObject.
/// The attributeType determines how to interpret the valueObject.
///
///     +----------------+---------+-----------------+----------------------+------------------------------+
///     |TYPE = SEQUENCE | LENGTH  |  attributeType  |   attributeVersion   | attributeValue = valueObject |
///     +----------------+---------+-----------------+----------------------+------------------------------+
struct ASN1Sequence {

    var attributeType = Int32(0)
    var attributeVersion = Int32(0)
    var valueObject = ASN1Object()
}

/// An ASN1 Object in the form TLV (Type, Length, Value), where Value is located at the valuePointer.
///
///     ↓ pointerBefore            ↓ valuePointer     ↓ pointerAfter
///     +----------------+---------+------------------+---------------
///     |type            | length  |   value          |  …
///     +----------------+---------+------------------+---------------
///
/// - Note: This object cannot ensure that its pointers are safe, guarantee this from the outside.
struct ASN1Object {

    fileprivate(set) var type = Int32(0)
    fileprivate(set) var length = 0
    fileprivate var xclass = Int32(0) // only needed for calling into OpenSSL

    fileprivate(set) var pointerBefore: UnsafePointer<UInt8>?
    fileprivate(set) var valuePointer: UnsafePointer<UInt8>?
    fileprivate(set) var pointerAfter: UnsafePointer<UInt8>?

    fileprivate init() {}
}

extension ASN1Object {

    /// Reads the TLV tuple using OpenSSL, and advances the Pointer to the Value part.
    ///
    /// - Parameters:
    ///   - pointer: pointer to the begin of the Type
    ///   - limit: pointer to the end of the payload of interest (passed to OpenSSL)
    /// - Returns: The type, length and pointers to value begin and end are returned as an ASN1Object.
    static func next(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?, notBeyond limit: UnsafePointer<UInt8>) -> ASN1Object {
        guard let nonNilPointer = pointer else { return ASN1Object() }

        let maxLength = nonNilPointer.distance(to: limit)
        var objectInfo = ASN1Object()
        objectInfo.pointerBefore = pointer
        ASN1_get_object(&pointer, &objectInfo.length, &objectInfo.type, &objectInfo.xclass, maxLength)
        objectInfo.valuePointer = pointer
        objectInfo.pointerAfter = pointer?.advanced(by: objectInfo.length)
        return objectInfo
    }
}

// MARK: - Set

extension ASN1Object {

    /// true if it is an ASN1 Set
    var isOfASN1SetType: Bool {
        return type == V_ASN1_SET
    }
}

// MARK: - Sequence

extension ASN1Object {

    /// Parses a sequence and it's value container, moves the pointer to the attribute value's value portion.
    func sequenceValue(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?, notBeyond limit: UnsafePointer<UInt8>) -> ASN1Sequence? {
        // ASN1 Object type must be an ASN1 Sequence
        guard type == V_ASN1_SEQUENCE else { return nil }

        // Get Attribute value
        let attributeTypeObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)
        guard let attributeType = attributeTypeObject.intValue(byAdvancingPointer: &pointer) else { return nil }

        // Get Attribute Version
        let attributeVersionObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)
        guard let attributeVersion = attributeVersionObject.intValue(byAdvancingPointer: &pointer) else { return nil }

        /// Pointer is now here
        ///                                                                     ↓ (pointer)
        /// +----------------+---------+-----------------+----------------------+------------------------------+
        /// |TYPE = SEQUENCE | LENGTH  |  attributeType  |   attributeVersion   | attributeValue = valueObject |
        /// +----------------+---------+-----------------+----------------------+------------------------------+
        // Zooming in:
        // The value in ATTR VALUE is supposed to be an ASN1_OCTETSTRING object of the following form:
        /// ↓ (pointer)
        /// +------------------------+---------------+----------------+---------------+
        /// |TYPE = ASN1_OCTETSTRING | VALUE_LENGTH  |   VALUE_TYPE   |   VALUE_BYTES |
        /// +------------------------+---------------+----------------+---------------+

        let valueObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)

        // ASN1 Sequence value must be an ASN1 Octet String
        guard valueObject.type == V_ASN1_OCTET_STRING else { return nil }

        return ASN1Sequence(attributeType: Int32(attributeType), attributeVersion: Int32(attributeVersion), valueObject: valueObject)
    }
}

// MARK: - Wrapped

extension ASN1Object {

    var unwrapped: ASN1Object? {
        guard let endPointer = valuePointer?.advanced(by: length) else { return nil }

        var innerPointer = valuePointer
        return ASN1Object.next(byAdvancingPointer: &innerPointer, notBeyond: endPointer)
    }
}

// MARK: - Data

extension ASN1Object {

    var dataValue: Data? {
        guard let pointer = self.valuePointer else { return nil }

        return Data(bytes: pointer, count: length)
    }
}

// MARK: - Date

extension ASN1Object {

    /// If a date-string is wrapped in an V_ASN1_OCTET_STRING, use this instead of `dateValue`
    var unwrappedDateValue: Date? {
        return self.unwrapped?.dateValue
    }

    var dateValue: Date? {
        guard let string = self.stringValue else { return nil }

        return AppReceiptValidator.asn1DateFormatter.date(from: string)
    }
}

// MARK: - IntValue

extension ASN1Object {

    var intValue: Int64? {
        guard self.type == V_ASN1_INTEGER else { return nil }

        var pointer = self.valuePointer
        let integer = c2i_ASN1_INTEGER(nil, &pointer, self.length)
        defer {
            ASN1_INTEGER_free(integer)
        }
        let result = Int64(ASN1_INTEGER_get(integer))
        return result
    }

    func intValue(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?, length: Int? = nil) -> Int64? {
        let length = length ?? self.length
        pointer = pointer?.advanced(by: length)
        guard let intValue = self.intValue else { return nil }

        return intValue
    }
}

// MARK: - StringValue

extension ASN1Object {

    /// If a string is wrapped in an V_ASN1_OCTET_STRING, use this instead of `stringValue`
    var unwrappedStringValue: String? {
        return self.unwrapped?.stringValue
    }

    var stringValue: String? {
        guard let bytes = self.valuePointer else { return nil }

        switch self.type {
        case V_ASN1_UTF8STRING:
            let data = Data(bytes: bytes, count: self.length)
            return String(data: data, encoding: .utf8)
        case V_ASN1_IA5STRING:
            let data = Data(bytes: bytes, count: self.length)
            return String(data: data, encoding: .ascii)
        default:
            return nil
        }
    }
}
