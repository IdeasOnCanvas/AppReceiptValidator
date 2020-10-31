//
//  AppReceiptValidator.swift
//  AppReceiptValidator iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
@testable import ASN1Decoder
import Crypto
import CCryptoBoringSSL

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

    func checkSignatureAuthenticity(pkcs7: ASN1Decoder.PKCS7, appleRootCertificateData: Data) throws {
        guard let signature = pkcs7.signatures?.first else { throw Error.receiptNotSigned }
        // 1. signatureData is correct, checked with ASN1Crypto
        guard let signatureData = signature.signatureData else { throw Error.receiptNotSigned }
        // 2. Receipt Data matches, checked with ASN1Crypto
        guard let receiptData = pkcs7.mainBlock.findOid(.pkcs7data)?.parent?.sub?.last?.sub(0)?.rawValue else { throw Error.receiptNotSigned }

        // 1. Read public key from cert
        let bio = CCryptoBoringSSL_BIO_new(CCryptoBoringSSL_BIO_s_mem())
        _ = appleRootCertificateData.withUnsafeBytes { pointer in
            CCryptoBoringSSL_BIO_write(bio, pointer.baseAddress, Int32(appleRootCertificateData.count))
        }
        let cert = CCryptoBoringSSL_d2i_X509_bio(bio, nil)
        let pubKey = CCryptoBoringSSL_X509_get_pubkey(cert)

        // 2. Init verify digest
        let ctx = CCryptoBoringSSL_EVP_MD_CTX_create()
        CCryptoBoringSSL_EVP_MD_CTX_init(ctx)
        let resultInit = CCryptoBoringSSL_EVP_DigestVerifyInit(ctx,
                                                               nil,
                                                               CCryptoBoringSSL_EVP_sha1(),
                                                               nil,
                                                               pubKey)
        let receiptDataArray = Array(receiptData)
        var resultUpdate: Int32 = 0
        // 3. Add message to be checked
        receiptDataArray.withUnsafeBytes { pointer in
            resultUpdate = CCryptoBoringSSL_EVP_DigestVerifyUpdate(ctx, pointer.baseAddress, receiptDataArray.count)
        }

        // 4. Verify signature
        var signatureDataArray = Array(signatureData)
        let resultFinal = CCryptoBoringSSL_EVP_DigestVerifyFinal(ctx, &signatureDataArray, signatureDataArray.count)

        let rootCert =  pkcs7.certificates[0]
        try self.verifyAuthenticity(x509Certificate: rootCert, receiptData: receiptData, signatureData: signatureData)
        // TODO: Remove redudant CCrypto* based signature verification,  uncomment all lines in below method to enable Sec* based verification, cleanup ssl resources
        print("Results init \(resultInit) update \(resultUpdate) final \(resultFinal)")
    }

    func verifyAuthenticity(x509Certificate: X509Certificate, receiptData: Data, signatureData: Data) throws {
        guard let secureKey = x509Certificate.publicKey?.secKey else { throw Error.receiptSignatureInvalid }

        var verifyError: Unmanaged<CFError>? = nil
        // TODO: This shouldn't be hardcoded. Should be read from the receipt instead.
        let alg = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA1
        guard SecKeyVerifySignature(secureKey, alg, receiptData as CFData, signatureData as CFData, &verifyError),
              verifyError == nil else {

            throw Error.receiptSignatureInvalid
        }
    }
}

// MARK: - Parsing of properties

private extension AppReceiptValidator {

    // swiftlint:disable:next cyclomatic_complexity
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

        return (receipt: receipt, unofficialReceipt: .init(entries: []))
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

// MARK: -  X509PublicKey SecKey

extension X509PublicKey {

    var secKey: SecKey? {
        guard let publicKeyDerEncoded = derEncodedKey else { return nil }
        var attributes: [String: Any] = [kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
        switch algOid {
        case OID.rsaEncryption.rawValue:
            attributes[kSecAttrKeyType as String] = kSecAttrKeyTypeRSA
        case OID.ecPublicKey.rawValue:
            attributes[kSecAttrKeyType as String] = kSecAttrKeyTypeEC
        default:
            return nil
        }
        var error: Unmanaged<CFError>?
        return SecKeyCreateWithData(publicKeyDerEncoded as CFData, attributes as CFDictionary, &error)
    }
}
