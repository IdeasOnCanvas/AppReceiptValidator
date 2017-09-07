//
//  ReceiptValidationParameters.swift
//  Hekate
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

public struct ReceiptValidationParameters {
    public var receiptOrigin: ReceiptOrigin = .installedInMainBundle
    public var validateSignaturePresence: Bool = true
    public var validateSignatureAuthenticity: Bool = true
    public var validateHash: Bool = true
    public var deviceIdentifier: ReceiptDeviceIdentifier = .installed
    public let rootCertificateOrigin: RootCertificateOrigin = .cerFileInMainBundle

    public func with(block: (inout ReceiptValidationParameters) -> Void) -> ReceiptValidationParameters {
        var copy = self
        block(&copy)
        return copy
    }

    public static var allSteps: ReceiptValidationParameters {
        return ReceiptValidationParameters()
    }

    func loadReceiptData() throws -> Data {
        switch receiptOrigin {
        case .data(let data):
            return data
        case .installedInMainBundle:
            guard let receiptUrl = Bundle.main.appStoreReceiptURL,
                (try? receiptUrl.checkResourceIsReachable()) ?? false,
                let data = try? Data(contentsOf: receiptUrl) else {
                    throw ReceiptValidationError.couldNotFindReceipt
            }
            return data
        }
    }

    func loadAppleRootCertificateData() throws -> Data {
        guard let appleRootCertificateURL = Bundle.main.url(forResource: "AppleIncRootCertificate", withExtension: "cer"),
            let appleRootCertificateData = try? Data(contentsOf: appleRootCertificateURL) else {
                throw ReceiptValidationError.appleRootCertificateNotFound
        }
        return appleRootCertificateData

    }

    func getDeviceIdentifierData() throws -> Data {
        switch deviceIdentifier {
        case .data(let data):
            return data
        case .installed:
            if let data = ReceiptValidationParameters.installedDeviceIdentifierData {
                return data
            } else {
                throw ReceiptValidationError.deviceIdentifierNotDeterminable
            }
        }
    }
}

// MARK: - ReceiptOrigin

public enum ReceiptOrigin {
    case installedInMainBundle
    case data(Data)
}

// MARK: - ReceiptDeviceIdentifier

public enum ReceiptDeviceIdentifier {
    case installed
    case data(Data)

    public init?(base64Encoded: String) {
        guard let data = Data(base64Encoded: base64Encoded) else {
            return nil
        }
        self = .data(data)
    }
}

// MARK: - RootCertificateOrigin

public enum RootCertificateOrigin {
    /// Expects a AppleIncRootCertificate.cer in main bundle
    case cerFileInMainBundle
}
