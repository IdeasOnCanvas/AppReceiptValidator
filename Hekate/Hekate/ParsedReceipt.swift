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
    public var inAppPurchaseReceipts: [ParsedInAppPurchaseReceipt]?
    public var originalAppVersion: String?
    public var receiptCreationDate: Date?
    public var expirationDate: Date?

    public init(bundleIdentifier: String?, bundleIdData: Data?, appVersion: String?, opaqueValue: Data?, sha1Hash: Data?, originalAppVersion: String?, receiptCreationDate: Date?, expirationDate: Date?) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleIdData = bundleIdData
        self.appVersion = appVersion
        self.opaqueValue = opaqueValue
        self.sha1Hash = sha1Hash
        self.originalAppVersion = originalAppVersion
        self.receiptCreationDate = receiptCreationDate
        self.expirationDate = expirationDate
    }

    public init() {}
}

// MARK: - Equatable

extension ParsedReceipt: Equatable { }

public func == (lhs: ParsedReceipt, rhs: ParsedReceipt) -> Bool {
    return lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.bundleIdData == rhs.bundleIdData &&
        lhs.appVersion == rhs.appVersion &&
        lhs.opaqueValue == rhs.opaqueValue &&
        lhs.sha1Hash == rhs.sha1Hash &&
        lhs.originalAppVersion == rhs.originalAppVersion &&
        lhs.receiptCreationDate == rhs.receiptCreationDate &&
        lhs.expirationDate == rhs.expirationDate
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

extension ParsedInAppPurchaseReceipt: Equatable { }

public func == (lhs: ParsedInAppPurchaseReceipt, rhs: ParsedInAppPurchaseReceipt) -> Bool {
    return lhs.quantity == rhs.quantity &&
        lhs.productIdentifier == rhs.productIdentifier &&
        lhs.transactionIdentifier == rhs.transactionIdentifier &&
        lhs.originalTransactionIdentifier == rhs.originalTransactionIdentifier &&
        lhs.purchaseDate == rhs.purchaseDate &&
        lhs.originalPurchaseDate == rhs.originalPurchaseDate &&
        lhs.subscriptionExpirationDate == rhs.subscriptionExpirationDate &&
        lhs.cancellationDate == rhs.cancellationDate &&
        lhs.webOrderLineItemId == rhs.webOrderLineItemId
}
