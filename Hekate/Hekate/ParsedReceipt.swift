//
//  ParsedReceipt.swift
//  Hekate
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

public struct ParsedReceipt {
    public var bundleIdentifier: String?
    public var bundleIdData: Data?
    public var appVersion: String?
    public var opaqueValue: Data?
    public var sha1Hash: Data?
    public var originalAppVersion: String?
    public var receiptCreationDate: Date?
    public var expirationDate: Date?
    public var inAppPurchaseReceipts: [ParsedInAppPurchaseReceipt] = []

    public init(bundleIdentifier: String?, bundleIdData: Data?, appVersion: String?, opaqueValue: Data?, sha1Hash: Data?, originalAppVersion: String?, receiptCreationDate: Date?, expirationDate: Date?, inAppPurchaseReceipts: [ParsedInAppPurchaseReceipt]) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleIdData = bundleIdData
        self.appVersion = appVersion
        self.opaqueValue = opaqueValue
        self.sha1Hash = sha1Hash
        self.originalAppVersion = originalAppVersion
        self.receiptCreationDate = receiptCreationDate
        self.expirationDate = expirationDate
        self.inAppPurchaseReceipts = inAppPurchaseReceipts
    }

    public init() {}
}

// MARK: - Equatable

extension ParsedReceipt: AutoEquatable {}

// MARK: - CustomStringConvertible

extension ParsedReceipt: CustomStringConvertible {
    public var description: String {
        let formatter = StringFormatter()
        let props: [(String, String)]  = [
            ("bundleIdentifier", formatter.format(bundleIdentifier)),
            ("bundleIdData", formatter.format(bundleIdData)),
            ("appVersion", formatter.format(appVersion)),
            ("opaqueValue", formatter.format(opaqueValue)),
            ("sha1Hash", formatter.format(sha1Hash)),
            ("originalAppVersion", formatter.format(originalAppVersion)),
            ("receiptCreationDate", formatter.format(receiptCreationDate)),
            ("expirationDate", formatter.format(expirationDate)),
            ("inAppPurchaseReceipts", formatter.format(inAppPurchaseReceipts))
        ]
        return "ParsedReceipt(\n" + formatter.format(props) + "\n)"
    }
}


// MARK: - ParsedInAppPurchaseReceipt

public struct ParsedInAppPurchaseReceipt {
    public var quantity: Int?
    public var productIdentifier: String?
    public var transactionIdentifier: String?
    public var originalTransactionIdentifier: String?
    public var purchaseDate: Date?
    public var originalPurchaseDate: Date?
    public var subscriptionExpirationDate: Date?
    public var cancellationDate: Date?
    public var webOrderLineItemId: Int?
    public init(quantity: Int?, productIdentifier: String?, transactionIdentifier: String?, originalTransactionIdentifier: String?, purchaseDate: Date?, originalPurchaseDate: Date?, subscriptionExpirationDate: Date?, cancellationDate: Date?, webOrderLineItemId: Int?) {
        self.quantity = quantity
        self.productIdentifier = productIdentifier
        self.transactionIdentifier = transactionIdentifier
        self.originalTransactionIdentifier = originalTransactionIdentifier
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.cancellationDate = cancellationDate
        self.webOrderLineItemId = webOrderLineItemId
    }

    public init() {}
}

// MARK: - Equatable

extension ParsedInAppPurchaseReceipt: AutoEquatable {}

// MARK: - CustomStringConvertible

extension ParsedInAppPurchaseReceipt: CustomStringConvertible {
    public var description: String {
        let formatter = StringFormatter()
        let props: [(String, String)]  = [
            ("quantity", formatter.format(quantity)),
            ("productIdentifier", formatter.format(productIdentifier)),
            ("transactionIdentifier", formatter.format(transactionIdentifier)),
            ("originalTransactionIdentifier", formatter.format(originalTransactionIdentifier)),
            ("purchaseDate", formatter.format(purchaseDate)),
            ("originalPurchaseDate", formatter.format(originalPurchaseDate)),
            ("subscriptionExpirationDate", formatter.format(subscriptionExpirationDate)),
            ("cancellationDate", formatter.format(cancellationDate)),
            ("webOrderLineItemId", formatter.format(webOrderLineItemId))
        ]
        return "ParsedInAppPurchaseReceipt(\n" + formatter.format(props) + "\n)"
    }
}

// MARK: - Custom String Conversion

private struct StringFormatter {
    let fallback = "nil"

    func format(_ inAppPurchaseReceipts: [ParsedInAppPurchaseReceipt]?, indentation: String = "    ") -> String {
        guard let inAppPurchaseReceipts = inAppPurchaseReceipts else {
            return fallback
        }
        guard !inAppPurchaseReceipts.isEmpty else {
            return "[]"
        }
        return "[\n" + inAppPurchaseReceipts.map({ $0.description.replacingOccurrences(of: "\n", with: "\n" + indentation) }).joined(separator: ",\n") + "\n]"
    }

    func format(_ pairs: [(String, String)]) -> String {
        return pairs.map({ (key, value) -> String in
            return self.format(key: key, value: value)
        }).joined(separator: ",\n")
    }

    func format(_ int: Int?) -> String {
        guard let int = int else {
            return fallback
        }
        return "\(int)"
    }

    func format(key: String, value: String, indentation: String = "    ") -> String {
        return "\(indentation)\(key): \(value)"
    }

    func format(_ data: Data?) -> String {
        guard let data = data else {
            return fallback
        }
        return data.base64EncodedString()
    }

    func format(_ date: Date?) -> String {
        guard let date = date else {
            return fallback
        }
        return ReceiptValidator.asn1DateFormatter.string(from: date)
    }

    func format(_ string: String?) -> String {
        return string ?? fallback
    }
}
