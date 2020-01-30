//
//  AppReceiptValidator.swift
//  AppReceiptValidator iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import CCryptoOpenSSL
import Foundation

/// Apple guide: https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html
///
/// Original inspiration for the Code: https://github.com/andrewcbancroft/SwiftyLocalReceiptValidator/blob/master/ReceiptValidator.swift
///
/// More: See README.md
/// - Note: If on iOS, use this only on Main Queue, because UIDevice is called
public struct AppReceiptValidator {

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Local Receipt Validation

    /// Validates a local receipt and returns the result using the passed parameters.
    public func validateReceipt(parameters: Parameters = Parameters.default) -> Result {
        var data: Data?
        var deviceIdData: Data?
        do {
            deviceIdData = parameters.deviceIdentifier.getData()
            guard let receiptData = parameters.receiptOrigin.loadData() else { throw Error.couldNotFindReceipt }

            data = receiptData
            let receiptContainer = try self.extractPKCS7Container(data: receiptData)

            if parameters.shouldValidateSignaturePresence {
                try self.checkSignaturePresence(pkcs7: receiptContainer)
            }
            if case .shouldValidate(let rootCertificateOrigin) = parameters.signatureValidation {
                guard let appleRootCertificateData = rootCertificateOrigin.loadData() else { throw Error.appleRootCertificateNotFound }

                try self.checkSignatureAuthenticity(pkcs7: receiptContainer, appleRootCertificateData: appleRootCertificateData)
            }

            let receipt = try self.parseReceipt(pkcs7: receiptContainer).receipt

            try self.validateProperties(receipt: receipt, validations: parameters.propertyValidations)

            if parameters.shouldValidateHash {
                guard let deviceIdentifierData = deviceIdData else { throw Error.deviceIdentifierNotDeterminable }

                try self.validateHash(receipt: receipt, deviceIdentifierData: deviceIdentifierData)
            }
            return .success(receipt, receiptData: receiptData, deviceIdentifier: deviceIdData)
        } catch {
            assert(error is AppReceiptValidator.Error)
            return .error(error as? AppReceiptValidator.Error ?? .unknown, receiptData: data, deviceIdentifier: deviceIdData)
        }
    }

    public func validateProperties(receipt: Receipt, validations: [Parameters.PropertyValidation]) throws {
        for validation in validations {
            try validation.validateProperty(of: receipt)
        }
    }

    /// Parse a local receipt without any validation.
    ///
    /// - Parameter origin: How to load the receipt.
    /// - Returns: The parsed receipt.
    /// - Throws: Especially Error.couldNotFindReceipt if the receipt cannot be loaded/found.
    public func parseReceipt(origin: Parameters.ReceiptOrigin) throws -> Receipt {
        guard let receiptData = origin.loadData() else { throw Error.couldNotFindReceipt }

        let receiptContainer = try self.extractPKCS7Container(data: receiptData)
        return try parseReceipt(pkcs7: receiptContainer).receipt
    }

    /// Parse the local receipt and it's unofficial attributes without any validation.
    ///
    /// - Parameter origin: How to load the receipt.
    /// - Returns: The parsed receipt.
    /// - Throws: Especially Error.couldNotFindReceipt if the receipt cannot be loaded/found.
    public func parseUnofficialReceipt(origin: Parameters.ReceiptOrigin) throws -> (receipt: Receipt, unofficialReceipt: UnofficialReceipt) {
        guard let receiptData = origin.loadData() else { throw Error.couldNotFindReceipt }

        let receiptContainer = try self.extractPKCS7Container(data: receiptData)
        return try parseReceipt(pkcs7: receiptContainer, parseUnofficialParts: true)
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

private extension AppReceiptValidator {

    func validateHash(receipt: Receipt, deviceIdentifierData: Data) throws {
        // Make sure that the Receipt instances has non-nil values needed for hash comparison
        guard let receiptOpaqueValueData = receipt.opaqueValue else { throw Error.incorrectHash }
        guard let receiptBundleIdData = receipt.bundleIdData else { throw Error.incorrectHash }
        guard let receiptHashData = receipt.sha1Hash else { throw Error.incorrectHash }

        // Compute the hash for your app & device

        // Set up the hashing context
        var computedHash = [UInt8](repeating: 0, count: 20)
        var sha1Context = SHA_CTX()

        SHA1_Init(&sha1Context)
        _ = deviceIdentifierData.withUnsafeBytes { pointer -> Void in
            SHA1_Update(&sha1Context, pointer.baseAddress, deviceIdentifierData.count)
        }
        _ = receiptOpaqueValueData.withUnsafeBytes { pointer -> Void in
            SHA1_Update(&sha1Context, pointer.baseAddress, receiptOpaqueValueData.count)
        }
        _ = receiptBundleIdData.withUnsafeBytes { pointer -> Void in
            SHA1_Update(&sha1Context, pointer.baseAddress, receiptBundleIdData.count)
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

private extension AppReceiptValidator {

    func extractPKCS7Container(data: Data) throws -> PKCS7Wrapper {
        let receiptBIO = BIOWrapper(data: data)
        let receiptPKCS7Container = d2i_PKCS7_bio(receiptBIO.bio, nil)

        guard let nonNullReceiptPKCS7Container = receiptPKCS7Container else { throw Error.emptyReceiptContents }

        let pkcs7Wrapper = PKCS7Wrapper(pkcs7: nonNullReceiptPKCS7Container)
        let pkcs7DataTypeCode = OBJ_obj2nid(receiptPKCS7Container?.pointee.d.sign.pointee.contents.pointee.type)

        guard pkcs7DataTypeCode == NID_pkcs7_data else { throw Error.emptyReceiptContents }

        return pkcs7Wrapper
    }
}

// MARK: - PKCS7 Signature checking

private extension AppReceiptValidator {

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

    #if os(Linux)
    private func verifyAuthenticity(x509Certificate: OpaquePointer, pkcs7: PKCS7Wrapper) throws {
        let x509CertificateStore = X509_STORE_new()
        defer {
            X509_STORE_free(x509CertificateStore)
        }
        X509_STORE_add_cert(x509CertificateStore, x509Certificate)
        let result = PKCS7_verify(pkcs7.pkcs7, nil, x509CertificateStore, nil, nil, 0)

        if result != 1 {
            throw Error.receiptSignatureInvalid
        }
    }
    #elseif os(macOS) || os(iOS)
    // Currently the Crypto package is using libressl on macOS which leads to other signature than on linux (openssl@1.1)
    private func verifyAuthenticity(x509Certificate: UnsafeMutablePointer<X509>, pkcs7: PKCS7Wrapper) throws {
        let x509CertificateStore = X509_STORE_new()
        defer {
            X509_STORE_free(x509CertificateStore)
        }
        X509_STORE_add_cert(x509CertificateStore, x509Certificate)
        let result = PKCS7_verify(pkcs7.pkcs7, nil, x509CertificateStore, nil, nil, 0)

        if result != 1 {
            throw Error.receiptSignatureInvalid
        }
    }
    #endif
}

// MARK: - Parsing of properties

private extension AppReceiptValidator {

    // swiftlint:disable:next cyclomatic_complexity
    func parseReceipt(pkcs7: PKCS7Wrapper, parseUnofficialParts: Bool = false) throws -> (receipt: Receipt, unofficialReceipt: UnofficialReceipt) {
        guard let contents = pkcs7.pkcs7.pointee.d.sign.pointee.contents, let octets = contents.pointee.d.data else { throw Error.malformedReceipt }
        guard let initialPointer = UnsafePointer(octets.pointee.data) else { throw Error.malformedReceipt }
        let length = Int(octets.pointee.length)
        var receipt = Receipt()
        var unofficialReceipt = UnofficialReceipt(entries: [])

        try self.parseASN1Set(pointer: initialPointer, length: length) { attributeType, value in
            guard let attribute = KnownReceiptAttribute(rawValue: attributeType) else {
                if parseUnofficialParts {
                    let entry = parseUnofficialReceiptEntry(attributeType: attributeType, value: value)
                    unofficialReceipt.entries.append(entry)
                }
                return
            }

            switch attribute {
            case .bundleIdentifier:
                receipt.bundleIdData = value.dataValue
                receipt.bundleIdentifier = value.unwrappedStringValue
            case .appVersion:
                receipt.appVersion = value.unwrappedStringValue
            case .opaqueValue:
                receipt.opaqueValue = value.dataValue
            case .sha1Hash:
                receipt.sha1Hash = value.dataValue
            case .inAppPurchaseReceipts:
                guard let pointer = value.valuePointer else { break }

                let iapReceipt = try parseInAppPurchaseReceipt(pointer: pointer, length: value.length)
                receipt.inAppPurchaseReceipts.append(iapReceipt)
            case .receiptCreationDate:
                receipt.receiptCreationDate = value.unwrappedDateValue
            case .originalAppVersion:
                receipt.originalAppVersion = value.unwrappedStringValue
            case .expirationDate:
                receipt.expirationDate = value.unwrappedDateValue
            }
        }

        return (receipt: receipt, unofficialReceipt: unofficialReceipt)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func parseInAppPurchaseReceipt(pointer: UnsafePointer<UInt8>, length: Int) throws -> InAppPurchaseReceipt {
        var inAppPurchaseReceipt = InAppPurchaseReceipt()
        try self.parseASN1Set(pointer: pointer, length: length) { attributeType, value in
            guard let attribute = KnownInAppPurchaseAttribute(rawValue: attributeType) else { return }
            guard let value = value.unwrapped else { return } // always unwrap set members

            switch attribute {
            case .quantity:
                inAppPurchaseReceipt.quantity = value.intValue
            case .productIdentifier:
                inAppPurchaseReceipt.productIdentifier = value.stringValue
            case .transactionIdentifier:
                inAppPurchaseReceipt.transactionIdentifier = value.stringValue
            case .originalTransactionIdentifier:
                inAppPurchaseReceipt.originalTransactionIdentifier = value.stringValue
            case .purchaseDate:
                inAppPurchaseReceipt.purchaseDate = value.dateValue
            case .originalPurchaseDate:
                inAppPurchaseReceipt.originalPurchaseDate = value.dateValue
            case .subscriptionExpirationDate:
                inAppPurchaseReceipt.subscriptionExpirationDate = value.dateValue
            case .cancellationDate:
                inAppPurchaseReceipt.cancellationDate = value.dateValue
            case .webOrderLineItemId:
                inAppPurchaseReceipt.webOrderLineItemId = value.intValue
            }
        }
        return inAppPurchaseReceipt
    }

    private func parseUnofficialReceiptEntry(attributeType: Int32, value: ASN1Object) -> UnofficialReceipt.Entry {
        switch KnownUnofficialReceiptAttribute(rawValue: attributeType) {
        case .some(let meaning):
            switch meaning.parsingType {
            case .string:
                return UnofficialReceipt.Entry(attributeNumber: attributeType, meaning: meaning, value: value.unwrappedStringValue.map { UnofficialReceipt.Entry.Value.string($0) })
            case .date:
                return UnofficialReceipt.Entry(attributeNumber: attributeType, meaning: meaning, value: value.unwrappedDateValue.map { UnofficialReceipt.Entry.Value.date($0) })
            case .data:
                return UnofficialReceipt.Entry(attributeNumber: attributeType, meaning: meaning, value: value.dataValue.map { UnofficialReceipt.Entry.Value.bytes($0) })
            }
        case .none:
            if let string = value.unwrappedStringValue {
                return UnofficialReceipt.Entry(attributeNumber: attributeType, meaning: nil, value: .string(string))
            }
            if let string = value.stringValue {
                return UnofficialReceipt.Entry(attributeNumber: attributeType, meaning: nil, value: .string(string))
            }
            return UnofficialReceipt.Entry(attributeNumber: attributeType, meaning: nil, value: value.dataValue.map { UnofficialReceipt.Entry.Value.bytes($0) })
        }
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

private extension AppReceiptValidator {

    /// See Receipt.swift for details and a link to Apple reference
    enum KnownReceiptAttribute: Int32 {
        case bundleIdentifier = 2
        case appVersion = 3
        case opaqueValue = 4
        case sha1Hash = 5
        case inAppPurchaseReceipts = 17
        case receiptCreationDate = 12
        case originalAppVersion = 19
        case expirationDate = 21
    }

    /// See Receipt.swift for details and a link to Apple reference
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

extension AppReceiptValidator {

    public enum Result {

        case success(Receipt, receiptData: Data, deviceIdentifier: Data?)
        case error(AppReceiptValidator.Error, receiptData: Data?, deviceIdentifier: Data?)

        public var receipt: Receipt? {
            switch self {
            case .success(let receipt, _, _):
                return receipt
            case .error:
                return nil
            }
        }

        public var error: AppReceiptValidator.Error? {
            switch self {
            case .success:
                return nil
            case .error(let error, _, _):
                return error
            }
        }

        /// The receipt data if it could be loaded
        public var receiptData: Data? {
            switch self {
            case .success(_, let data, _):
                return data
            case .error(_, let data, _):
                return data
            }
        }

        /// The device identifier if it could be determined
        public var deviceIdentifier: Data? {
            switch self {
            case .success(_, _, let data):
                return data
            case .error(_, _, let data):
                return data
            }
        }
    }
}

// MARK: - Error

extension AppReceiptValidator {

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
        case couldNotGetExpectedPropertyValue
        case propertyValueMismatch
        case unknown
    }
}
