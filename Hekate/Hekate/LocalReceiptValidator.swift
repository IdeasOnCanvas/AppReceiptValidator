//
//  LocalReceiptValidator.swift
//  Hekate iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import StoreKit

/// Apple guide: https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html
///
/// Original inspiration for the Code: https://github.com/andrewcbancroft/SwiftyLocalReceiptValidator/blob/master/ReceiptValidator.swift
///
/// More: See README.md
/// - Note: If on iOS, use this only on Main Queue, because UIDevice is called
public struct LocalReceiptValidator {

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Local Receipt Validation

    /// Validates a local receipt and returns the result using the parameters `LocalReceiptValidator.Parameters.allSteps`, which can be further configured in the passed block.
    public func validateReceipt(configuration: (inout Parameters) -> Void) -> Result {
        return validateReceipt(parameters: Parameters.allSteps.with(block: configuration))
    }

    /// Validates a local receipt and returns the result using the passed parameters.
    public func validateReceipt(parameters: Parameters = Parameters.allSteps) -> Result {
        do {
            guard let receiptData = parameters.receiptOrigin.loadData() else { throw Error.couldNotFindReceipt }

            let receiptContainer = try self.extractPKCS7Container(data: receiptData)

            if parameters.validateSignaturePresence {
                try self.checkSignaturePresence(pkcs7: receiptContainer)
            }
            if parameters.validateSignatureAuthenticity {
                guard let appleRootCertificateData = parameters.rootCertificateOrigin.loadData() else { throw Error.appleRootCertificateNotFound }

                try self.checkSignatureAuthenticity(pkcs7: receiptContainer, appleRootCertificateData: appleRootCertificateData)
            }
            let parsedReceipt = try parseReceipt(pkcs7: receiptContainer)

            if parameters.validateHash {
                guard let deviceIdentifierData = parameters.deviceIdentifier.getData() else { throw Error.deviceIdentifierNotDeterminable }

                print("Device identifier used (BASE64): \(deviceIdentifierData.base64EncodedString())")

                try self.validateHash(receipt: parsedReceipt, deviceIdentifierData: deviceIdentifierData)
            }
            return .success(parsedReceipt)
        } catch {
            assert(error is LocalReceiptValidator.Error)
            return .error(error as? LocalReceiptValidator.Error ?? .unknown)
        }
    }

    /// Parse a local receipt without any validation.
    ///
    /// - Parameter origin: How to load the receipt.
    /// - Returns: The Parsed receipt.
    /// - Throws: A Error. Especially Error.couldNotFindReceipt if the receipt cannot be loaded/found.
    public func parseReceipt(origin: Parameters.ReceiptOrigin) throws -> ParsedReceipt {
        guard let receiptData = origin.loadData() else {
            throw Error.couldNotFindReceipt
        }

        let receiptContainer = try extractPKCS7Container(data: receiptData)
        return try parseReceipt(pkcs7: receiptContainer)
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

// MARK: - Full Validation

private extension LocalReceiptValidator {

    func validateHash(receipt: ParsedReceipt, deviceIdentifierData: Data) throws {
        // Make sure that the ParsedReceipt instances has non-nil values needed for hash comparison
        guard let receiptOpaqueValueData = receipt.opaqueValue else { throw Error.incorrectHash }
        guard let receiptBundleIdData = receipt.bundleIdData else { throw Error.incorrectHash }
        guard let receiptHashData = receipt.sha1Hash else { throw Error.incorrectHash }

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
        if computedHashData != receiptHashData {
            throw Error.incorrectHash
        }
    }
}

// MARK: - PKCS7 Extraction

private extension LocalReceiptValidator {

    func extractPKCS7Container(data: Data) throws -> PKCS7Wrapper {
        let receiptBIO = BIOWrapper(data: data)
        let receiptPKCS7Container = d2i_PKCS7_bio(receiptBIO.bio, nil)

        guard let nonNullReceiptPKCS7Container = receiptPKCS7Container else { throw Error.emptyReceiptContents }

        let pkcs7Wrapper = PKCS7Wrapper(pkcs7: nonNullReceiptPKCS7Container)
        let pkcs7DataTypeCode = OBJ_obj2nid(pkcs7_d_sign(receiptPKCS7Container).pointee.contents.pointee.type)

        guard pkcs7DataTypeCode == NID_pkcs7_data else { throw Error.emptyReceiptContents }

        return pkcs7Wrapper
    }
}

// MARK: - PKCS7 Signature checking

private extension LocalReceiptValidator {

    func checkSignaturePresence(pkcs7: PKCS7Wrapper) throws {
        let pkcs7SignedTypeCode = OBJ_obj2nid(pkcs7.pkcs7.pointee.type)

        guard pkcs7SignedTypeCode == NID_pkcs7_signed else { throw Error.receiptNotSigned }
    }

    func checkSignatureAuthenticity(pkcs7: PKCS7Wrapper, appleRootCertificateData: Data) throws {
        let appleRootCertificateBIO = BIOWrapper(data: appleRootCertificateData)

        guard let appleRootCertificateX509 = d2i_X509_bio(appleRootCertificateBIO.bio, nil) else { throw Error.malformedAppleRootCertificate }

        defer {
            X509_free(appleRootCertificateX509)
        }
        try self.verifyAuthenticity(x509Certificate: appleRootCertificateX509, pkcs7: pkcs7)
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
            throw Error.receiptSignatureInvalid
        }
    }
}

// MARK: - Parsing of properties

private extension LocalReceiptValidator {

    // swiftlint:disable:next cyclomatic_complexity
    func parseReceipt(pkcs7: PKCS7Wrapper) throws -> ParsedReceipt {
        guard let contents = pkcs7.pkcs7.pointee.d.sign.pointee.contents, let octets = contents.pointee.d.data else { throw Error.malformedReceipt }
        guard let initialPointer = UnsafePointer(octets.pointee.data) else { throw Error.malformedReceipt }
        let length = Int(octets.pointee.length)
        var parsedReceipt = ParsedReceipt()

        try self.parseASN1Set(pointer: initialPointer, length: length) { attributeType, value in
            guard let attribute = KnownReceiptAttribute(rawValue: attributeType) else { return }

            switch attribute {
            case .bundleIdentifier:
                parsedReceipt.bundleIdData = value.dataValue
                parsedReceipt.bundleIdentifier = value.unwrappedStringValue
            case .appVersion:
                parsedReceipt.appVersion = value.unwrappedStringValue
            case .opaqueValue:
                parsedReceipt.opaqueValue = value.dataValue
            case .sha1Hash:
                parsedReceipt.sha1Hash = value.dataValue
            case .inAppPurchaseReceipts:
                guard let pointer = value.valuePointer else { break }

                let iapReceipt = try parseInAppPurchaseReceipt(pointer: pointer, length: value.length)
                parsedReceipt.inAppPurchaseReceipts.append(iapReceipt)
            case .receiptCreationDate:
                parsedReceipt.receiptCreationDate = value.unwrappedDateValue
            case .originalAppVersion:
                parsedReceipt.originalAppVersion = value.unwrappedStringValue
            case .expirationDate:
                parsedReceipt.expirationDate = value.unwrappedDateValue
                break
            }
        }
        return parsedReceipt
    }

    private func parseInAppPurchaseReceipt(pointer: UnsafePointer<UInt8>, length: Int) throws -> ParsedInAppPurchaseReceipt {
        var parsedInAppPurchaseReceipt = ParsedInAppPurchaseReceipt()
        try self.parseASN1Set(pointer: pointer, length: length) { attributeType, value in
            guard let attribute = KnownInAppPurchaseAttribute(rawValue: attributeType) else { return }

            switch attribute {
            case .quantity:
                parsedInAppPurchaseReceipt.quantity = value.intValue
            case .productIdentifier:
                parsedInAppPurchaseReceipt.productIdentifier = value.unwrappedStringValue
            case .transactionIdentifier:
                parsedInAppPurchaseReceipt.transactionIdentifier = value.unwrappedStringValue
            case .originalTransactionIdentifier:
                parsedInAppPurchaseReceipt.originalTransactionIdentifier = value.unwrappedStringValue
            case .purchaseDate:
                parsedInAppPurchaseReceipt.purchaseDate = value.unwrappedDateValue
            case .originalPurchaseDate:
                parsedInAppPurchaseReceipt.originalPurchaseDate = value.unwrappedDateValue
            case .subscriptionExpirationDate:
                parsedInAppPurchaseReceipt.subscriptionExpirationDate = value.unwrappedDateValue
            case .cancellationDate:
                parsedInAppPurchaseReceipt.cancellationDate = value.unwrappedDateValue
            case .webOrderLineItemId:
                parsedInAppPurchaseReceipt.webOrderLineItemId = value.intValue
            }
        }
        return parsedInAppPurchaseReceipt
    }

    private func parseASN1Set(pointer initialPointer: UnsafePointer<UInt8>, length: Int, valueAttributeAction: (_ attributeType: Int32, _ value: ASN1Object) throws -> Void) throws {
        var pointer: UnsafePointer<UInt8>? = initialPointer
        let limit = initialPointer.advanced(by: length)

        /// Make sure we're pointing to an ASN1 Set, and move the pointer forward
        guard ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit).isOfASN1SetType else { throw Error.malformedReceipt }

        // Decode Payload

        // Step through payload (ASN1 Set) and parse each ASN1 Sequence within (ASN1 Sets contain one or more ASN1 Sequences)
        while pointer != nil && pointer! < limit {
            // Get next ASN1 Object. Parses length and type, and moves the pointer forward
            let sequenceObject = ASN1Object.next(byAdvancingPointer: &pointer, notBeyond: limit)

            // Attempt to interpret it as a ASN1 Sequence
            guard let sequence = sequenceObject.sequenceValue(byAdvancingPointer: &pointer, notBeyond: limit) else { throw Error.malformedReceipt }

            // Extract and assign value from the current sequence
            try valueAttributeAction(sequence.attributeType, sequence.valueObject)

            // move pointer to end of current sequence
            pointer = sequenceObject.pointerAfter
        }
    }
}

// MARK: Receipt ASN1 Sequence Attribute Types

private extension LocalReceiptValidator {

    /// See ParsedReceipt.swift for details and a link to Apple reference
    enum KnownReceiptAttribute: Int32 {
        case bundleIdentifier = 2
        case appVersion = 3
        case opaqueValue = 4
        case sha1Hash = 5
        case inAppPurchaseReceipts = 17
        case receiptCreationDate = 12
        case originalAppVersion = 19
        case expirationDate = 21

        // Unofficial list found (not necessarily complete):
        // - 18: some date in the past
        // - 8: some date in the past, same as receiptCreationDate possibly
        // - 0: String, probably Provisioning-Type, Encountered Values: "Production", "ProductionSandbox"
        // - 10: String, probably Age Description, example Value "4+"
        // - and of unknown type 14(L=3), 25(L=3), 11(L=4), 13(L=4), 1(L=6), 9(L=6), 16(L=6), 15(L=8), 7(L=66), 6(L=69 variable)
    }

    /// See ParsedReceipt.swift for details and a link to Apple reference
    enum KnownInAppPurchaseAttribute: Int32 {
        case quantity = 1701
        case productIdentifier = 1702
        case transactionIdentifier = 1703
        case originalTransactionIdentifier = 1705
        case purchaseDate = 1704
        case originalPurchaseDate = 1706
        case subscriptionExpirationDate = 1708
        case cancellationDate = 1712
        case webOrderLineItemId = 1711
    }
}

// MARK: - Result

extension LocalReceiptValidator {

    public enum Result {

        case success(ParsedReceipt)
        case error(LocalReceiptValidator.Error)

        public var receipt: ParsedReceipt? {
            switch self {
            case .success(let receipt):
                return receipt
            case .error:
                return nil
            }
        }

        public var error: LocalReceiptValidator.Error? {
            switch self {
            case .success:
                return nil
            case .error(let error):
                return error
            }
        }
    }
}

// MARK: - Error

extension LocalReceiptValidator {

    public enum Error: Int, Swift.Error {
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
        case unknown
    }
}
