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
    /// Use .allSteps to initialize the standard parameters.
    public struct Parameters {

        public var receiptOrigin: ReceiptOrigin = .installedInMainBundle
        public var validateSignaturePresence: Bool = true
        public var validateSignatureAuthenticity: Bool = true
        public var validateHash: Bool = true
        public var deviceIdentifier: DeviceIdentifier = .currentDevice
        public let rootCertificateOrigin: RootCertificateOrigin = .cerFileInMainBundle

        /// Configure an instance with a block
        public func with(block: (inout Parameters) -> Void) -> Parameters {
            var copy = self
            block(&copy)
            return copy
        }

        /// Use .allSteps to initialize
        private init() {}

        public static var allSteps: Parameters {
            return Parameters()
        }
    }
}

// MARK: - ReceiptOrigin

/// Used for obtaining the receipt data to parse or validate.
///
/// - installedInMainBundle: Loads it from Bundle.main.appStoreReceiptURL.
/// - data: Loads specific data.
extension LocalReceiptValidator.Parameters {
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

/// Used for calculating/validating the SHA1-Hash part of a receipt.
///
/// - currentDevice: Obtains it from the system location: MAC Adress on macOS, deviceIdentifierForVendor on iOS
/// - data: Specific Data to use
public extension LocalReceiptValidator.Parameters {
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

/// Instructs how to find the Apple root certificate for receipt validation.
///
/// - cerFileInMainBundle: Expects a AppleIncRootCertificate.cer in main bundle with the name "AppleIncRootCertificate.cer"
/// - data: Specific Data to use
extension LocalReceiptValidator.Parameters {
    public enum RootCertificateOrigin {
        case cerFileInMainBundle
        case data(Data)

        public func loadData() -> Data? {
            switch self {
            case .data(let data):
                return data
            case .cerFileInMainBundle:
                guard let appleRootCertificateURL = Bundle.main.url(forResource: "AppleIncRootCertificate", withExtension: "cer") else { return nil }
                guard let appleRootCertificateData = try? Data(contentsOf: appleRootCertificateURL) else { return nil }

                return appleRootCertificateData
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
