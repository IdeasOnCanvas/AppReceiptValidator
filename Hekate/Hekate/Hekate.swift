//
//  Hekate.swift
//  Hekate iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import StoreKit

// Original inspiration https://github.com/andrewcbancroft/SwiftyLocalReceiptValidator/blob/master/ReceiptValidator.swift

public struct ReceiptValidator {
    public init() {}

    public func validateReceipt(configuration: (inout ReceiptValidationParameters) -> Void = { params in }) -> ReceiptValidationResult {
        return validateReceipt(parameters: ReceiptValidationParameters.allSteps.with(block: configuration))
    }

    public func validateReceipt(parameters: ReceiptValidationParameters) -> ReceiptValidationResult {
        do {
            let receiptData: Data = try parameters.loadReceiptData()

            let receiptContainer = try extractPKCS7Container(data: receiptData)

            if parameters.validateSignaturePresence {
                try checkSignaturePresence(pkcs7: receiptContainer)
            }
            if parameters.validateSignatureAuthenticity {
                let appleRootCertificateData = try parameters.loadAppleRootCertificateData()
                try checkSignatureAuthenticity(pkcs7: receiptContainer, appleRootCertificateData: appleRootCertificateData)
            }
            let parsedReceipt = try parse(pkcs7: receiptContainer)

            if parameters.validateHash {
                let deviceIdentifierData = try parameters.getDeviceIdentifierData()
                print("Device identifier used (BASE64): \(deviceIdentifierData.base64EncodedString())")
                try validateHash(receipt: parsedReceipt, deviceIdentifierData: deviceIdentifierData)
            }
            return .success(parsedReceipt)
        } catch {
            return .error(error as! ReceiptValidationError) // swiftlint:disable:this force_cast
        }
    }

    fileprivate func validateHash(receipt: ParsedReceipt, deviceIdentifierData: Data) throws {
        // Make sure that the ParsedReceipt instances has non-nil values needed for hash comparison
        guard let receiptOpaqueValueData = receipt.opaqueValue else { throw ReceiptValidationError.incorrectHash }
        guard let receiptBundleIdData = receipt.bundleIdData else { throw ReceiptValidationError.incorrectHash }
        guard let receiptHashData = receipt.sha1Hash else { throw ReceiptValidationError.incorrectHash }

        // Compute the hash for your app & device

        // Set up the hashing context
        var computedHash = [UInt8](repeating: 0, count: 20)
        var sha1Context = SHA_CTX()

        SHA1_Init(&sha1Context)

        deviceIdentifierData.withUnsafeBytes { pointer -> Void in
            SHA1_Update(&sha1Context, pointer, deviceIdentifierData.count)
        }
        receiptOpaqueValueData.withUnsafeBytes { pointer -> Void in
            SHA1_Update(&sha1Context, pointer, receiptOpaqueValueData.count)
        }
        receiptBundleIdData.withUnsafeBytes { pointer -> Void in
            SHA1_Update(&sha1Context, pointer, receiptBundleIdData.count)
        }
        SHA1_Final(&computedHash, &sha1Context)

        let computedHashData = Data(bytes: &computedHash, count: 20)

        // Compare the computed hash with the receipt's hash
        guard computedHashData == receiptHashData else { throw ReceiptValidationError.incorrectHash }
    }

    /// Uses receipt-conform representation of dates like "2017-01-01T12:00:00Z"
    public static let asn1DateFormatter: DateFormatter = {
        // Date formatter code from https://www.objc.io/issues/17-security/receipt-validation/#parsing-the-receipt
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }()
}

// MARK: - PKCS7 Extraction

private extension ReceiptValidator {
    func extractPKCS7Container(data: Data) throws -> PKCS7Wrapper {
        let receiptBIO = BIOWrapper(data: data)

        let receiptPKCS7Container = d2i_PKCS7_bio(receiptBIO.bio, nil)

        guard let nonNullReceiptPKCS7Container = receiptPKCS7Container else {
            throw ReceiptValidationError.emptyReceiptContents
        }

        let pkcs7Wrapper = PKCS7Wrapper(pkcs7: nonNullReceiptPKCS7Container)

        let pkcs7DataTypeCode = OBJ_obj2nid(pkcs7_d_sign(receiptPKCS7Container).pointee.contents.pointee.type)

        guard pkcs7DataTypeCode == NID_pkcs7_data else {
            throw ReceiptValidationError.emptyReceiptContents
        }

        return pkcs7Wrapper
    }
}

// MARK: - PKCS7 Signature checking

private extension ReceiptValidator {
    func checkSignaturePresence(pkcs7: PKCS7Wrapper) throws {
        let pkcs7SignedTypeCode = OBJ_obj2nid(pkcs7.pkcs7.pointee.type)

        guard pkcs7SignedTypeCode == NID_pkcs7_signed else {
            throw ReceiptValidationError.receiptNotSigned
        }
    }

    func checkSignatureAuthenticity(pkcs7: PKCS7Wrapper, appleRootCertificateData: Data) throws {
        let appleRootCertificateBIO = BIOWrapper(data: appleRootCertificateData)

        guard let appleRootCertificateX509 = d2i_X509_bio(appleRootCertificateBIO.bio, nil) else {
            throw ReceiptValidationError.malformedAppleRootCertificate
        }
        defer {
            X509_free(appleRootCertificateX509)
        }
        try verifyAuthenticity(x509Certificate: appleRootCertificateX509, pkcs7: pkcs7)
    }

    private func verifyAuthenticity(x509Certificate: UnsafeMutablePointer<X509>, pkcs7: PKCS7Wrapper) throws {
        let x509CertificateStore = X509_STORE_new()
        defer {
            X509_STORE_free(x509CertificateStore)
        }
        X509_STORE_add_cert(x509CertificateStore, x509Certificate)

        OpenSSL_add_all_digests()

        let result = PKCS7_verify(pkcs7.pkcs7, nil, x509CertificateStore, nil, nil, 0)

        if result != 1 {
            throw ReceiptValidationError.receiptSignatureInvalid
        }
    }
}

// MARK: - Parsing of properties

private extension ReceiptValidator {
    // swiftlint:disable:next cyclomatic_complexity
    func parse(pkcs7: PKCS7Wrapper) throws -> ParsedReceipt {

        var parsedReceipt = ParsedReceipt()

        guard let contents = pkcs7.pkcs7.pointee.d.sign.pointee.contents, let octets = contents.pointee.d.data else {
            throw ReceiptValidationError.malformedReceipt
        }

        var pointer = UnsafePointer(octets.pointee.data)
        let endOfPayload = pointer!.advanced(by: Int(octets.pointee.length))

        let set = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: endOfPayload)

        // Payload must be an ASN1 Set
        guard set.type == V_ASN1_SET else {
            throw ReceiptValidationError.malformedReceipt
        }

        // Decode Payload
        // Step through payload (ASN1 Set) and parse each ASN1 Sequence within (ASN1 Sets contain one or more ASN1 Sequences)
        while pointer != nil && pointer! < endOfPayload {

            /// ↓ (currentASN1PayloadLocation)
            /// |TYPE = SEQUENCE | LENGTH  |   ATTR TYPE   |   ATTR VERS   |      ATTR VALUE      |
            /// +----------------+---------+---------------+---------------+----------------------+
            /// |    ASN1_INT    |ASN1_INT |   ASN1_INT    |   ASN1_INT    |   ASN1_OCTETSTRING   |
            /// +----------------+---------+---------------+---------------+----------------------+
            ///                    length  |  determines   |  (ignored)    |   actual value data  |
            ///                      of    |  attribute    |
            ///                     VALUE  |  value type   |

            // Get next ASN1 Object. Parses length and type, and moves the pointer further to ATTR TYPE
            let sequenceObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: endOfPayload)
            guard let sequence = sequenceObject.sequence(byAdvancingPointer: &pointer, notBeyond: endOfPayload) else {
                throw ReceiptValidationError.malformedReceipt
            }
            let value = sequence.valueObject

            // Decode values

            switch sequence.attributeType {
            case 2:
                parsedReceipt.bundleIdData = value.dataValue
                parsedReceipt.bundleIdentifier = value.unwrappedStringValue
            case 3:
                parsedReceipt.appVersion = value.unwrappedStringValue
            case 4:
                parsedReceipt.opaqueValue = value.dataValue
            case 5:
                parsedReceipt.sha1Hash = value.dataValue
            case 17:
                var mutableValueLocation = value.valuePointer
                let iapReceipt = try parseInAppPurchaseReceipt(currentInAppPurchaseASN1PayloadLocation: &mutableValueLocation, payloadLength: value.length)
                parsedReceipt.inAppPurchaseReceipts.append(iapReceipt)
            case 12:
                parsedReceipt.receiptCreationDate = value.unwrappedDateValue
            case 19:
                parsedReceipt.originalAppVersion = value.unwrappedStringValue
            case 21:
                parsedReceipt.expirationDate = value.unwrappedDateValue
            default:
                print("Unknown attributeType: \(sequence.attributeType), length: \(value.length)")
                break
            }
            pointer = sequenceObject.pointerAfter
        }

        return parsedReceipt
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func parseInAppPurchaseReceipt(currentInAppPurchaseASN1PayloadLocation: inout UnsafePointer<UInt8>?, payloadLength: Int) throws -> ParsedInAppPurchaseReceipt {
        var quantity: Int?
        var productIdentifier: String?
        var transactionIdentifier: String?
        var originalTransactionIdentifier: String?
        var purchaseDate: Date?
        var originalPurchaseDate: Date?
        var subscriptionExpirationDate: Date?
        var cancellationDate: Date?
        var webOrderLineItemId: Int?

        let endOfPayload = currentInAppPurchaseASN1PayloadLocation!.advanced(by: payloadLength)
        var type = Int32(0)
        var xclass = Int32(0)
        var length = 0

        ASN1_get_object(&currentInAppPurchaseASN1PayloadLocation, &length, &type, &xclass, payloadLength)

        // Payload must be an ASN1 Set
        guard type == V_ASN1_SET else {
            throw ReceiptValidationError.malformedInAppPurchaseReceipt
        }

        // Decode Payload
        // Step through payload (ASN1 Set) and parse each ASN1 Sequence within (ASN1 Sets contain one or more ASN1 Sequences)
        while currentInAppPurchaseASN1PayloadLocation! < endOfPayload {

            // Get next ASN1 Sequence
            ASN1_get_object(&currentInAppPurchaseASN1PayloadLocation, &length, &type, &xclass, currentInAppPurchaseASN1PayloadLocation!.distance(to: endOfPayload))

            // ASN1 Object type must be an ASN1 Sequence
            guard type == V_ASN1_SEQUENCE else {
                throw ReceiptValidationError.malformedInAppPurchaseReceipt
            }

            // Attribute type of ASN1 Sequence must be an Integer
            guard let attributeType = decodeASN1Integer(advancingPointer: &currentInAppPurchaseASN1PayloadLocation, length: currentInAppPurchaseASN1PayloadLocation!.distance(to: endOfPayload)) else {
                throw ReceiptValidationError.malformedInAppPurchaseReceipt
            }

            // Attribute version of ASN1 Sequence must be an Integer
            guard decodeASN1Integer(advancingPointer: &currentInAppPurchaseASN1PayloadLocation, length: currentInAppPurchaseASN1PayloadLocation!.distance(to: endOfPayload)) != nil else {
                throw ReceiptValidationError.malformedInAppPurchaseReceipt
            }

            // Get ASN1 Sequence value
            ASN1_get_object(&currentInAppPurchaseASN1PayloadLocation, &length, &type, &xclass, currentInAppPurchaseASN1PayloadLocation!.distance(to: endOfPayload))

            // ASN1 Sequence value must be an ASN1 Octet String
            guard type == V_ASN1_OCTET_STRING else {
                throw ReceiptValidationError.malformedInAppPurchaseReceipt
            }

            // Decode attributes
            switch attributeType {
            case 1701:
                var startOfQuantity = currentInAppPurchaseASN1PayloadLocation
                quantity = decodeASN1Integer(advancingPointer: &startOfQuantity, length: length)
            case 1702:
                var startOfProductIdentifier = currentInAppPurchaseASN1PayloadLocation
                productIdentifier = decodeASN1String(pointer: &startOfProductIdentifier, length: length)
            case 1703:
                var startOfTransactionIdentifier = currentInAppPurchaseASN1PayloadLocation
                transactionIdentifier = decodeASN1String(pointer: &startOfTransactionIdentifier, length: length)
            case 1705:
                var startOfOriginalTransactionIdentifier = currentInAppPurchaseASN1PayloadLocation
                originalTransactionIdentifier = decodeASN1String(pointer: &startOfOriginalTransactionIdentifier, length: length)
            case 1704:
                var startOfPurchaseDate = currentInAppPurchaseASN1PayloadLocation
                purchaseDate = decodeASN1Date(startOfDate: &startOfPurchaseDate, length: length)
            case 1706:
                var startOfOriginalPurchaseDate = currentInAppPurchaseASN1PayloadLocation
                originalPurchaseDate = decodeASN1Date(startOfDate: &startOfOriginalPurchaseDate, length: length)
            case 1708:
                var startOfSubscriptionExpirationDate = currentInAppPurchaseASN1PayloadLocation
                subscriptionExpirationDate = decodeASN1Date(startOfDate: &startOfSubscriptionExpirationDate, length: length)
            case 1712:
                var startOfCancellationDate = currentInAppPurchaseASN1PayloadLocation
                cancellationDate = decodeASN1Date(startOfDate: &startOfCancellationDate, length: length)
            case 1711:
                var startOfWebOrderLineItemId = currentInAppPurchaseASN1PayloadLocation
                webOrderLineItemId = decodeASN1Integer(advancingPointer: &startOfWebOrderLineItemId, length: length)
            default:
                break
            }

            currentInAppPurchaseASN1PayloadLocation = currentInAppPurchaseASN1PayloadLocation!.advanced(by: length)
        }

        return ParsedInAppPurchaseReceipt(quantity: quantity,
                                          productIdentifier: productIdentifier,
                                          transactionIdentifier: transactionIdentifier,
                                          originalTransactionIdentifier: originalTransactionIdentifier,
                                          purchaseDate: purchaseDate,
                                          originalPurchaseDate: originalPurchaseDate,
                                          subscriptionExpirationDate: subscriptionExpirationDate,
                                          cancellationDate: cancellationDate,
                                          webOrderLineItemId: webOrderLineItemId)
    }

    private func decodeASN1Integer(advancingPointer pointer: inout UnsafePointer<UInt8>?, length: Int) -> Int? {
        let object = ASN1Object.next(byAdvancingPointer: &pointer, maxLength: length)
        pointer = object.pointerAfter
        return object.intValue
    }

    private func decodeASN1String(pointer: inout UnsafePointer<UInt8>?, length: Int) -> String? {
        let object = ASN1Object.next(byAdvancingPointer: &pointer, maxLength: length)
        pointer = object.pointerAfter
        return object.stringValue
    }

    private func decodeASN1Date(startOfDate datePointer: inout UnsafePointer<UInt8>?, length: Int) -> Date? {
        if let dateString = decodeASN1String(pointer: &datePointer, length:length) {
            return ReceiptValidator.asn1DateFormatter.date(from: dateString)
        }
        return nil
    }
}

// MARK: - ReceiptValidationResult

public enum ReceiptValidationResult {
    case success(ParsedReceipt)
    case error(ReceiptValidationError)

    public var receipt: ParsedReceipt? {
        switch self {
        case .success(let receipt):
            return receipt
        case .error:
            return nil
        }
    }

    public var error: ReceiptValidationError? {
        switch self {
        case .success:
            return nil
        case .error(let error):
            return error
        }
    }
}

// MARK: - ReceiptValidationError

public enum ReceiptValidationError: Int, Error {
    case couldNotFindReceipt
    case emptyReceiptContents
    case receiptNotSigned
    case appleRootCertificateNotFound
    case receiptSignatureInvalid
    case malformedReceipt
    case malformedInAppPurchaseReceipt
    case incorrectHash
    case deviceIdentifierNotDeterminable
    case malformedAppleRootCertificate
}
