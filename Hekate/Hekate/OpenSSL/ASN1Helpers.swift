//
//  ASN1Helpers.swift
//  Hekate
//
//  Created by Hannes Oud on 07.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

struct ASN1Sequence {
    var attributeType = Int32(0)
    var attributeVersion = Int32(0)
    var valueObject = ASN1Object()
}

struct ASN1Object {
    fileprivate(set) var type = Int32(0)
    fileprivate(set) var xclass = Int32(0)
    fileprivate(set) var length = 0
    fileprivate(set) var pointerBefore: UnsafePointer<UInt8>?
    fileprivate(set) var valuePointer: UnsafePointer<UInt8>?
    fileprivate(set) var pointerAfter: UnsafePointer<UInt8>?

    fileprivate init() {}
}

extension ASN1Object {
    static func next(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?, notBeyond limit: UnsafePointer<UInt8>) -> ASN1Object {
        guard let nonNilPointer = pointer else {
            let object = ASN1Object()
            return object
        }
        return ASN1Object.next(byAdvancingPointer: &pointer, maxLength: nonNilPointer.distance(to: limit))
    }

    static func next(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?, maxLength: Int) -> ASN1Object {
        var objectInfo = ASN1Object()
        objectInfo.pointerBefore = pointer
        ASN1_get_object(&pointer, &objectInfo.length, &objectInfo.type, &objectInfo.xclass, maxLength)
        objectInfo.valuePointer = pointer
        objectInfo.pointerAfter = pointer?.advanced(by: objectInfo.length)
        return objectInfo
    }
}

// MARK: - ASN1Sequence

extension ASN1Object {
    func sequence(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?, notBeyond limit: UnsafePointer<UInt8>) -> ASN1Sequence? {
        guard type == V_ASN1_SEQUENCE else {
            return nil
        }

        // ASN1 Object type must be an ASN1 Sequence
        guard type == V_ASN1_SEQUENCE else {
            return nil
        }

        // Get Attribute value
        let attributeTypeObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)
        guard let attributeType = attributeTypeObject.intValue(byAdvancingPointer: &pointer) else {
            return nil
        }

        // Get Attribute Version
        let attributeVersionObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)
        guard let attributeVersion = attributeVersionObject.intValue(byAdvancingPointer: &pointer) else {
            return nil
        }

        /// Pointer is now here
        ///                                            ↓ (pointer)
        /// +----------------+---------+---------------+---------------+----------------------+
        /// |TYPE = SEQUENCE | LENGTH  |   ATTR TYPE   |   ATTR VERS   |      ATTR VALUE      |
        /// +----------------+---------+---------------+---------------+----------------------+

        // Begin looking at the value

        // The value in ATTR VALUE is supposed to be an ASN1_OCTETSTRING object of the following form:
        /// ↓ (currentASN1PayloadLocation)
        /// +------------------------+---------------+----------------+---------------+
        /// |TYPE = ASN1_OCTETSTRING | VALUE_LENGTH  |   VALUE_TYPE   |   VALUE_BYTES |
        /// +------------------------+---------------+----------------+---------------+

        let valueObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)

        // ASN1 Sequence value must be an ASN1 Octet String
        guard valueObject.type == V_ASN1_OCTET_STRING else {
            return nil
        }
        return ASN1Sequence(attributeType: Int32(attributeType), attributeVersion: Int32(attributeVersion), valueObject: valueObject)
    }
}

// MARK: - IntValue

extension ASN1Object {
    var intValue: Int? {
        guard type == V_ASN1_INTEGER else {
            return nil
        }
        var pointer = valuePointer
        let integer = c2i_ASN1_INTEGER(nil, &pointer, length)
        defer {
            ASN1_INTEGER_free(integer)
        }
        let result = ASN1_INTEGER_get(integer)
        return result
    }

    func intValue(byAdvancingPointer pointer: inout UnsafePointer<UInt8>?) -> Int? {
        pointer = pointer?.advanced(by: self.length)
        guard let intValue = self.intValue else {
            return nil
        }
        return intValue
    }
}

// MARK: - StringValue

extension ASN1Object {
    var stringValue: String? {
        guard let bytes = valuePointer else {
            return nil
        }
        switch type {
        case V_ASN1_UTF8STRING:
            let data = Data(bytes: bytes, count: length)
            return String(data: data, encoding: .utf8)
        case V_ASN1_IA5STRING:
            let data = Data(bytes: bytes, count: length)
            return String(data: data, encoding: .ascii)
        default:
            return nil
        }
    }
}
