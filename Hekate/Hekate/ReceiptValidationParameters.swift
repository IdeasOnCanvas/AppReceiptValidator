//
//  ReceiptValidationParameters.swift
//  Hekate
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

/// Describes how to validate a receipt, and how/where to obtain the dependencies (receipt, deviceIdentifier, apple root certificate)
/// Use .allSteps to initialize the standard parameters.
public struct ReceiptValidationParameters {

    public var receiptOrigin: ReceiptOrigin = .installedInMainBundle
    public var validateSignaturePresence: Bool = true
    public var validateSignatureAuthenticity: Bool = true
    public var validateHash: Bool = true
    public var deviceIdentifier: ReceiptDeviceIdentifier = .currentDevice
    public let rootCertificateOrigin: RootCertificateOrigin = .cerFileInMainBundle

    /// Configure an instance with a block
    public func with(block: (inout ReceiptValidationParameters) -> Void) -> ReceiptValidationParameters {
        var copy = self
        block(&copy)
        return copy
    }

    /// Use .allSteps to initialize
    private init() {}

    public static var allSteps: ReceiptValidationParameters {
        return ReceiptValidationParameters()
    }
}

// MARK: - ReceiptOrigin

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

// MARK: - ReceiptDeviceIdentifier

public enum ReceiptDeviceIdentifier {

    case currentDevice
    case data(Data)

    public init?(base64Encoded: String) {
        guard let data = Data(base64Encoded: base64Encoded) else { return nil }
        self = .data(data)
    }

    public func getData() -> Data? {
        switch self {
        case .data(let data):
            return data
        case .currentDevice:
            if let data = ReceiptDeviceIdentifier.installedDeviceIdentifierData {
                return data
            } else {
                return nil
            }
        }
    }
}

// MARK: - RootCertificateOrigin

public enum RootCertificateOrigin {

    /// Expects a AppleIncRootCertificate.cer in main bundle
    case cerFileInMainBundle

    public func loadData() -> Data? {
        guard let appleRootCertificateURL = Bundle.main.url(forResource: "AppleIncRootCertificate", withExtension: "cer") else { return nil }
        guard let appleRootCertificateData = try? Data(contentsOf: appleRootCertificateURL) else { return nil }

        return appleRootCertificateData
    }
}
