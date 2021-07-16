//
//  AppReceiptValidator.swift
//  AppReceiptValidator iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import ASN1Decoder
import CCryptoBoringSSL
import Crypto
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

                try self.checkSignatureAuthenticity(pkcs7: receiptContainer, appleRootCertificateData: appleRootCertificateData, rawData: data)
            }
            let receipt = try self.parseReceipt(pkcs7: receiptContainer).receipt

            try self.validateProperties(receipt: receipt, validations: parameters.propertyValidations)

            if parameters.shouldValidateHash {
                guard let deviceIdentifierData = deviceIdData else { throw Error.deviceIdentifierNotDeterminable }

                try self.validateHash(receipt: receipt, deviceIdentifierData: deviceIdentifierData)
            }

            return .success(receipt, receiptData: receiptData, deviceIdentifier: deviceIdData)
        } catch {
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
        var ctx = SHA_CTX()

        CCryptoBoringSSL_SHA1_Init(&ctx)
        deviceIdentifierData.withUnsafeBytes { pointer -> Void in
            CCryptoBoringSSL_SHA1_Update(&ctx, pointer.baseAddress, deviceIdentifierData.count)
        }
        receiptOpaqueValueData.withUnsafeBytes { pointer -> Void in
            CCryptoBoringSSL_SHA1_Update(&ctx, pointer.baseAddress, receiptOpaqueValueData.count)
        }
        receiptBundleIdData.withUnsafeBytes { pointer -> Void in
            CCryptoBoringSSL_SHA1_Update(&ctx, pointer.baseAddress, receiptBundleIdData.count)
        }
        CCryptoBoringSSL_SHA1_Final(&computedHash, &ctx)

        let computedHashData = Data(bytes: &computedHash, count: 20)
        // Compare the computed hash with the receipt's hash
        if computedHashData != receiptHashData {
            throw Error.incorrectHash
        }
    }
}

// MARK: - PKCS7 Extraction

private extension AppReceiptValidator {

    func extractPKCS7Container(data: Data) throws -> ASN1Decoder.PKCS7 {
        do {
            return try PKCS7(data: data)
        } catch {
            throw Error.emptyReceiptContents
        }
    }
}

// MARK: - PKCS7 Signature checking

private extension AppReceiptValidator {

    func checkSignaturePresence(pkcs7: ASN1Decoder.PKCS7) throws {
        guard pkcs7.signatures?.isEmpty == false else { throw Error.receiptNotSigned }
    }

    func checkSignatureAuthenticity(pkcs7: ASN1Decoder.PKCS7, appleRootCertificateData: Data, rawData: Data?) throws {
        guard let signature = pkcs7.signatures?.first else { throw Error.receiptNotSigned }
        guard let signatureData = signature.signatureData else { throw Error.receiptNotSigned }
        guard let receiptData = pkcs7.mainBlock.findOid(.pkcs7data)?.parent?.sub?.last?.sub(0)?.rawValue else { throw Error.receiptNotSigned }

        let rootCert = pkcs7.certificates[0]
        try self.verifyAuthenticity(x509Certificate: rootCert, receiptData: receiptData, signatureData: signatureData)
    }

    func verifyAuthenticity(x509Certificate: X509Certificate, receiptData: Data, signatureData: Data) throws {
        // TODO: Migrate this from Security.framework to BoringSSL/Cryptokit to allow compilation on Linux
        #if !os(Linux)
        guard let key = x509Certificate.publicKey?.secKey,
              let algorithm = x509Certificate.publicKey?.secAlgorithm else { throw Error.receiptSignatureInvalid }

        var verifyError: Unmanaged<CFError>?
        guard SecKeyVerifySignature(key, algorithm, receiptData as CFData, signatureData as CFData, &verifyError),
              verifyError == nil else {
            throw Error.receiptSignatureInvalid
        }
        #endif
    }
}

// MARK: - Parsing of properties

private extension AppReceiptValidator {

    func parseReceipt(pkcs7: ASN1Decoder.PKCS7, parseUnofficialParts: Bool = false) throws -> (receipt: Receipt, unofficialReceipt: UnofficialReceipt) {
        guard let contents = pkcs7.receipt() else { throw Error.malformedReceipt }

        var receipt = Receipt()
        receipt.bundleIdentifier = contents.bundleIdentifier
        receipt.bundleIdData = contents.bundleIdentifierData
        receipt.appVersion = contents.bundleVersion
        receipt.opaqueValue = contents.opaqueValue
        receipt.sha1Hash = contents.sha1
        let purchases = contents.inAppPurchases ?? []
        receipt.inAppPurchaseReceipts = purchases.map { iap in
            var iapReceipt = InAppPurchaseReceipt()
            iapReceipt.cancellationDate = iap.cancellationDate
            iapReceipt.quantity = iap.quantity.map(Int64.init)
            iapReceipt.productIdentifier = iap.productId
            iapReceipt.transactionIdentifier = iap.transactionId
            iapReceipt.purchaseDate = iap.purchaseDate
            iapReceipt.originalPurchaseDate = iap.originalPurchaseDate
            iapReceipt.subscriptionExpirationDate = iap.expiresDate
            iapReceipt.originalTransactionIdentifier = iap.originalTransactionId
            iapReceipt.webOrderLineItemId = iap.webOrderLineItemId.map(Int64.init)
            return iapReceipt
        }
        receipt.receiptCreationDate = contents.receiptCreationDate
        receipt.originalAppVersion = contents.originalApplicationVersion
        receipt.expirationDate = contents.receiptExpirationDate

        return (receipt: receipt, unofficialReceipt: (parseUnofficialParts ? self.parseUnofficialReceipt(pkcs7: pkcs7) : .init(entries: [])))
    }

    func parseUnofficialReceipt(pkcs7: ASN1Decoder.PKCS7) -> UnofficialReceipt {
        guard let receiptBlock = pkcs7.mainBlock.findOid(.pkcs7data)?.parent?.sub?.last?.sub(0)?.sub(0),
              let items = receiptBlock.sub else { return .init(entries: []) }

        let entries: [UnofficialReceipt.Entry] = items.compactMap { item in
            guard let fieldType = (item.sub(0)?.value as? Data)?.toIntValue(),
                  KnownReceiptAttribute(rawValue: fieldType) == nil else { return nil }

            let fieldValueString = item.sub(2)?.asString
            if let meaning = KnownUnofficialReceiptAttribute(rawValue: fieldType) {
                switch meaning.parsingType {
                case .string:
                    if let string = fieldValueString {
                        return UnofficialReceipt.Entry(attributeNumber: fieldType, meaning: meaning, value: .string(string))
                    }
                case .date:
                    if let string = fieldValueString, let date = ReceiptDateFormatter.date(from: string) {
                        return UnofficialReceipt.Entry(attributeNumber: fieldType, meaning: meaning, value: .date(date))
                    }
                case .data:
                    if let data = item.sub(2)?.rawValue {
                        return UnofficialReceipt.Entry(attributeNumber: fieldType, meaning: meaning, value: .bytes(data))
                    }
                }
            }

            if let string = fieldValueString {
                return UnofficialReceipt.Entry(attributeNumber: fieldType, meaning: nil, value: .string(string))
            }
            return UnofficialReceipt.Entry(attributeNumber: fieldType, meaning: nil, value: item.sub(2)?.rawValue.map { .bytes($0) })
        }
        return UnofficialReceipt(entries: entries)
    }
}

// MARK: - ReceiptDateFormatter

extension AppReceiptValidator {

    /// Static formatting methods to use for string encoded date values in receipts
    public enum ReceiptDateFormatter {

        /// Uses receipt-conform representation of dates like "2017-01-01T12:00:00Z",
        /// as a fallback, dates like "2017-01-01T12:00:00.123Z" are also parsed.
        public static func date(from string: String) -> Date? {
            return self.asn1DateFormatter.date(from: string) // expected
                ?? self.fallbackDateFormatterWithMS.date(from: string) // try again with milliseconds
        }

        /// Returns receipt-conform string representation of dates like "2017-01-01T12:00:00Z",
        /// but if the date has sub-second fractions a millisecond representation like "2017-01-01T12:00:00.123Z" is returned.
        public static func string(from date: Date) -> String {
            if floor(date.timeIntervalSince1970) == date.timeIntervalSince1970 {
                // Integer seconds granularity is what we expect
                return self.asn1DateFormatter.string(from: date)
            } else {
                // millis seconds granularity is what we expect
                return self.fallbackDateFormatterWithMS.string(from: date)
            }
        }

        /// Uses receipt-conform representation of dates like "2017-01-01T12:00:00Z"
        static let asn1DateFormatter: DateFormatter = {
            // Date formatter code from https://www.objc.io/issues/17-security/receipt-validation/#parsing-the-receipt
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            return dateFormatter
        }()

        /// Uses receipt-conform representation of dates like "2017-01-01T12:00:00.123Z"
        ///
        /// This is not the officially intended format, but added after hearing reports about new format adding ms https://twitter.com/depth42/status/1314179654811607041
        private static let fallbackDateFormatterWithMS: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            return dateFormatter
        }()
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

// MARK: - X509PublicKey SecKey

extension X509PublicKey {

    #if !os(Linux)
    var secKey: SecKey? {
        guard let oid = self.algOid,
              let algorithm = OID(rawValue: oid),
              let publicKeyDerEncoded = derEncodedKey else { return nil }

        var attributes: [String: Any] = [kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
        switch algorithm {
        case .rsaEncryption:
            attributes[kSecAttrKeyType as String] = kSecAttrKeyTypeRSA
        case .ecPublicKey:
            attributes[kSecAttrKeyType as String] = kSecAttrKeyTypeEC
        default:
            return nil
        }
        var error: Unmanaged<CFError>?
        return SecKeyCreateWithData(publicKeyDerEncoded as CFData, attributes as CFDictionary, &error)
    }

    var secAlgorithm: SecKeyAlgorithm? {
        guard let oid = self.algOid,
              let algorithm = OID(rawValue: oid) else { return nil }

        switch algorithm {
        // We only support RSA for now
        case .rsaEncryption:
            return .rsaSignatureMessagePKCS1v15SHA1
        default:
            return nil
        }
    }
    #endif
}
