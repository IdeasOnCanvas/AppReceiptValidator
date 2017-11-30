//
//  LocalReceiptValidator+Parameters.swift
//  Hekate
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

public extension LocalReceiptValidator {

    /// Describes how to validate a receipt, and how/where to obtain the dependencies (receipt, deviceIdentifier, apple root certificate)
    /// Use .default to initialize the standard parameters. By default, no `propertyValidations` are active.
    public struct Parameters {

        // MARK: - Properties

        public var receiptOrigin: ReceiptOrigin = .installedInMainBundle
        public var shouldValidateSignaturePresence: Bool = true
        public var shouldValidateSignatureAuthenticity: Bool = true
        public var shouldValidateHash: Bool = true
        public var deviceIdentifier: DeviceIdentifier = .currentDevice
        public var rootCertificateOrigin: RootCertificateOrigin = .cerFileBundledWithHekate
        public var propertyValidations: [PropertyValidation] = []

        // MARK: - Lifecycle

        /// Or use .default to initialize a sensible defaults
        public init(receiptOrigin: ReceiptOrigin, shouldValidateSignaturePresence: Bool, shouldValidateSignatureAuthenticity: Bool, shouldValidateHash: Bool, deviceIdentifier: DeviceIdentifier, rootCertificateOrigin: RootCertificateOrigin, propertyValidations: [PropertyValidation]) {
            self.receiptOrigin = receiptOrigin
            self.shouldValidateSignaturePresence = shouldValidateSignaturePresence
            self.shouldValidateSignatureAuthenticity = shouldValidateSignatureAuthenticity
            self.shouldValidateHash = shouldValidateHash
            self.deviceIdentifier = deviceIdentifier
            self.rootCertificateOrigin = rootCertificateOrigin
        }

        /// Either use `.default` to get a default preset, or specify everything via the complete init(…) with all parameters.
        private init() {}

        public static var `default`: Parameters {
            return Parameters()
        }

        /// Configure an instance with a block
        public func with(block: (inout Parameters) -> Void) -> Parameters {
            var copy = self
            block(&copy)
            return copy
        }
    }
}

// MARK: - ReceiptOrigin

extension LocalReceiptValidator.Parameters {

    /// Used for obtaining the receipt data to parse or validate.
    ///
    /// - installedInMainBundle: Loads it from Bundle.main.appStoreReceiptURL.
    /// - data: Loads specific data.
    public enum ReceiptOrigin {

        case installedInMainBundle
        case data(Data)

        public func loadData() -> Data? {
            switch self {
            case .data(let data):
                return data
            case .installedInMainBundle:
                guard let receiptUrl = Bundle.main.appStoreReceiptURL else { return nil }
                guard (try? receiptUrl.checkResourceIsReachable()) ?? false else { return nil }
                guard let data = try? Data(contentsOf: receiptUrl) else { return nil }
                return data
            }
        }
    }
}

// MARK: - DeviceIdentifier

public extension LocalReceiptValidator.Parameters {

    /// Used for calculating/validating the SHA1-Hash part of a receipt.
    ///
    /// - currentDevice: Obtains it from the system location: MAC Adress on macOS, deviceIdentifierForVendor on iOS
    /// - data: Specific Data to use
    public enum DeviceIdentifier {

        case currentDevice
        case data(Data)

        public init?(base64Encoded: String) {
            guard let data = Data(base64Encoded: base64Encoded) else { return nil }
            self = .data(data)
        }

        public init(uuid: UUID) {
            self = .data(uuid.data)
        }

        public func getData() -> Data? {
            switch self {
            case .data(let data):
                return data
            case .currentDevice:
                if let data = DeviceIdentifier.installedDeviceIdentifierData {
                    return data
                } else {
                    return nil
                }
            }
        }
    }
}

// MARK: - RootCertificateOrigin

extension LocalReceiptValidator.Parameters {

    /// Instructs how to find the Apple root certificate for receipt validation.
    ///
    /// - cerFileBundledWithHekate: Uses the "AppleIncRootCertificate.cer" bundled with Hekate
    /// - data: Specific Data to use
    public enum RootCertificateOrigin {
        case cerFileBundledWithHekate
        case data(Data)

        public func loadData() -> Data? {
            switch self {
            case .data(let data):
                return data
            case .cerFileBundledWithHekate:
                guard let appleRootCertificateURL = Bundle(for: BundleToken.self).url(forResource: "AppleIncRootCertificate", withExtension: "cer") else { return nil }

                return try? Data(contentsOf: appleRootCertificateURL)
            }
        }
    }
    private class BundleToken {}
}


// MARK: - PropertyValidation

extension LocalReceiptValidator.Parameters {

    /// Compares a String property of a receipt with an info dictionary entry or a provided value.
    ///
    /// Apple recommends comparing against hard coded values. Note the platform dependence of `Receipt.appVersion`.
    ///
    /// See convieniences `bundleIdMatchingMainBundle`, `appVersionMatchingMainBundleIOS`, and `appVersionMatchingMainBundleMacOS`.
    ///
    /// - string: Compare a property with a hardcoded string (as recommended by apple)
    public enum PropertyValidation {

        case string(KeyPath<Receipt, String?>, expected: String?)

        /// Compares the receipts bundle id with the main bundle's info plist CFBundleIdentifier.
        public static var bundleIdMatchingMainBundle: PropertyValidation {
            return compareWithMainBundle(receiptProperty: \Receipt.bundleIdentifier, infoDictionaryKey: String(kCFBundleIdentifierKey))
        }

        /// Compares the receipts appVersion with the main bundle's info plist CFBundleVersionString, as adequate for iOS
        public static var appVersionMatchingMainBundleIOS: PropertyValidation {
            return compareWithMainBundle(receiptProperty: \Receipt.appVersion, infoDictionaryKey: String(kCFBundleVersionKey))
        }

        /// Compares the receipts appVersion with the main bundle's info plist CFBundleShortVersionString, as adequate for macOS
        public static var appVersionMatchingMainBundleMacOS: PropertyValidation {
            return compareWithMainBundle(receiptProperty: \Receipt.appVersion, infoDictionaryKey: "CFBundleShortVersionString")
        }

        private static func compareWithMainBundle(receiptProperty: KeyPath<Receipt, String?>, infoDictionaryKey: String) -> PropertyValidation {
            let expected = Bundle.main.infoDictionary?[infoDictionaryKey] as? String
            return .string(receiptProperty, expected: expected)
        }

        // MARK: Validation Execution

        /// Validates a receipts property. May throw Error.couldNotGetExpectedPropertyValue or Error.propertyValueMismatch.
        public func validateProperty(of receipt: Receipt) throws {
            let expected = self.getExpectedValue()

            if self.propertyValue(of: receipt) != expected {
                throw LocalReceiptValidator.Error.propertyValueMismatch
            }
        }

        // MARK: Value and Expected Value

        private func propertyValue(of receipt: Receipt) -> String? {
            switch self {
            case .string(let keyPath, _):
                return receipt[keyPath: keyPath]
            }
        }

        private func getExpectedValue() -> String? {
            switch self {
            case .string(_, let expected):
                return expected
            }
        }
    }
}

// MARK: - UUID + data

extension UUID {

    /// Get's the raw bytes of a Foundation UUID
    var data: Data {
        var rawUUID = self.uuid
        let data = withUnsafePointer(to: &rawUUID) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: uuid))
        }
        return data
    }
}
