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
import CommonCrypto
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

        // Set up the hashing context
        var computedHash = [UInt8](repeating: 0, count: 20)
        var sha1Context = CC_SHA1_CTX()

        CC_SHA1_Init(&sha1Context)
        deviceIdentifierData.withUnsafeBytes { pointer -> Void in
            CC_SHA1_Update(&sha1Context, pointer.baseAddress, UInt32(deviceIdentifierData.count))
        }
        receiptOpaqueValueData.withUnsafeBytes { pointer -> Void in
            CC_SHA1_Update(&sha1Context, pointer.baseAddress, UInt32(receiptOpaqueValueData.count))
        }
        receiptBundleIdData.withUnsafeBytes { pointer -> Void in
            CC_SHA1_Update(&sha1Context, pointer.baseAddress, UInt32(receiptBundleIdData.count))
        }
        CC_SHA1_Final(&computedHash, &sha1Context)

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
        guard let certificate = SecCertificateCreateWithData(nil, appleRootCertificateData as NSData) else { throw Error.malformedAppleRootCertificate }
        guard let key = SecCertificateCopyKey(certificate) else { throw Error.malformedAppleRootCertificate }
        guard let signature = pkcs7.signatures?.first else { throw Error.receiptNotSigned }
        guard let signatureData = signature.signatureAlgorithm?.rawValue else { throw Error.receiptNotSigned }
        let algorithm = SecKeyAlgorithm(rawValue: signature.disgestAlgorithmName! as NSString)

        let data = pkcs7.derData
        var computedHash = [UInt8](repeating: 0, count: 20)
        var sha1Context = CC_SHA1_CTX()

        CC_SHA1_Init(&sha1Context)

        pkcs7.derData.withUnsafeBytes { pointer -> Void in
            CC_SHA1_Update(&sha1Context, pointer.baseAddress, UInt32(data.count))
        }
        CC_SHA1_Final(&computedHash, &sha1Context)
        let computedHashData = Data(bytes: &computedHash, count: 20)
        var error: Unmanaged<CFError>? = nil


        var result = Array(signatureData)

        var rsa = RSA()
        var error2: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error2) as? Data else {
            dump(error2)
            return
        }

        var keyDataArray = Array(keyData)
        var key2: UnsafePointer<UInt8>? = UnsafePointer(&keyDataArray)
        var rsa2: UnsafeMutablePointer<RSA>? = UnsafeMutablePointer(&rsa)
        let rsa3 = CCryptoBoringSSL_RSA_public_key_from_bytes(&keyDataArray, keyDataArray.count)
        var out = [UInt8](repeating: 0, count: 256)

        // Try to decrypt the signature data
        let result2 = CCryptoBoringSSL_RSA_public_decrypt(signatureData.count, &result, &out, rsa3, RSA_NO_PADDING)
      //  let result = SecKeyCreateEncryptedData(key, .r, signatureData as NSData, &error)
//        let result = SecKeyVerifySignature(key, .rsaSignatureDigestPKCS1v15SHA1,
//                                           computedHashData as NSData,
//                                           signatureData as NSData,
//                                           &error)

//        let appleRootCertificateBIO = BIOWrapper(data: appleRootCertificateData)
//
//        guard let appleRootCertificateX509 = d2i_X509_bio(appleRootCertificateBIO.bio, nil)
//
//        defer {
//            X509_free(appleRootCertificateX509)
//        }
//        try self.verifyAuthenticity(x509Certificate: appleRootCertificateX509, pkcs7: pkcs7)
    }

    private func verifyAuthenticity(x509Certificate: OpaquePointer, pkcs7: ASN1Decoder.PKCS7) throws {
//        let x509CertificateStore = X509_STORE_new()
//        defer {
//            X509_STORE_free(x509CertificateStore)
//        }
//        X509_STORE_add_cert(x509CertificateStore, x509Certificate)
//        let result = PKCS7_verify(pkcs7.pkcs7, nil, x509CertificateStore, nil, nil, 0)
//
//        if result != 1 {
//            throw Error.receiptSignatureInvalid
//        }
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
