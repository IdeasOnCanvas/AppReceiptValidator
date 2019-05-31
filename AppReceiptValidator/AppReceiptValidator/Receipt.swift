//
//  Receipt.swift
//  AppReceiptValidator
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

/// Receipts are made up of a number of fields. This represents all fields that are available locally when parsing a receipt file in ASN.1 form.
///
/// See [Apple Reference](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html)
public struct Receipt: Equatable {

    /// The app’s bundle identifier. This corresponds to the value of `CFBundleIdentifier` in the Info.plist file.
    /// Use this value to validate if the receipt was indeed generated for your app. ASN.1 Field Type 2.
    public internal(set) var bundleIdentifier: String?

    /// The app’s bundle identifier as bytes, used, with other data, to compute the SHA-1 hash during validation.
    public internal(set) var bundleIdData: Data?

    /// The app’s version number. **This is platform dependent!**
    /// This corresponds to the value of `CFBundleVersion` (in iOS) or `CFBundleShortVersionString` (in macOS) in the Info.plist.
    /// ASN.1 Field Type 3.
    public internal(set) var appVersion: String?

    /// An opaque value used, with other data, to compute the SHA-1 hash during validation. ASN.1 Field Type 4.
    public internal(set) var opaqueValue: Data?

    /// A SHA-1 hash, used to validate the receipt. ASN.1 Field Type 5.
    public internal(set) var sha1Hash: Data?

    /// The version of the app that was originally purchased.
    /// This corresponds to the value of `CFBundleVersion` (in iOS) or `CFBundleShortVersionString` (in macOS) in the Info.plist
    /// file when the purchase was originally made. ASN.1 Field Type 19.
    /// - Note: In the **sandbox** environment, the value of this field is **always “1.0”**.
    public internal(set) var originalAppVersion: String?

    /// The date when the app receipt was created. ASN.1 Field Type 12.
    /// - Note: When validating a receipt, use this date to validate the receipt’s signature.
    public internal(set) var receiptCreationDate: Date?

    /// The date that the app receipt expires. ASN.1 Field Type 21.
    /// - Note: This key is present only for apps purchased through the Volume Purchase Program. If this key is not present, the receipt does not expire.
    /// - Note: When validating a receipt, compare this date to the current date to determine whether the receipt is expired. Do not try to use this date to calculate any other information, such as the time remaining before expiration.
    public internal(set) var expirationDate: Date?

    /// The receipt for a in-app purchases. ASN.1 Field Type 17.
    /// - Note: In the ASN.1 file, there are multiple fields that all have type 17, each of which contains a single in-app purchase receipt.
    /// - Note: The in-app purchase receipt for a consumable product is added to the receipt when the purchase is made.
    ///         It is kept in the receipt until your app finishes that transaction.
    ///         After that point, it is removed from the receipt the next time the receipt is updated - for example,
    ///         when the user makes another purchase or if your app explicitly refreshes the receipt.
    ///         The in-app purchase receipt for a non-consumable product, auto-renewable subscription, non-renewing subscription, or free subscription remains in the receipt indefinitely.
    public internal(set) var inAppPurchaseReceipts: [InAppPurchaseReceipt] = []

    public init(bundleIdentifier: String?, bundleIdData: Data?, appVersion: String?, opaqueValue: Data?, sha1Hash: Data?, originalAppVersion: String?, receiptCreationDate: Date?, expirationDate: Date?, inAppPurchaseReceipts: [InAppPurchaseReceipt]) {
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

// MARK: - CustomStringConvertible

extension Receipt: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        let formatter = StringFormatter()
        let props: [(String, String)]  = [
            ("bundleIdentifier", formatter.format(self.bundleIdentifier)),
            ("bundleIdData", formatter.format(self.bundleIdData)),
            ("appVersion", formatter.format(self.appVersion)),
            ("opaqueValue", formatter.format(self.opaqueValue)),
            ("sha1Hash", formatter.format(self.sha1Hash)),
            ("originalAppVersion", formatter.format(self.originalAppVersion)),
            ("receiptCreationDate", formatter.format(self.receiptCreationDate)),
            ("expirationDate", formatter.format(self.expirationDate)),
            ("inAppPurchaseReceipts", formatter.format(self.inAppPurchaseReceipts))
        ]
        return "Receipt(\n" + formatter.format(props) + "\n)"
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - InAppPurchaseReceipt

/// An In-App-Purchase Receipt as Parsed from a receipt file.
///
/// Documentation was obtained from: https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html
///
/// The following fields are part of JSON communication but not part of the parsed version (matched Sept 2017):
/// - Subscription Expiration Intent
/// - Subscription Retry Flag
/// - Subscription Trial Period
/// - Cancellation Reason
/// - App Item ID
/// - External Version Identifier
/// - Subscription Auto Renew Status
/// - Subscription Auto Renew Preference
/// - Subscription Price Consent Status
public struct InAppPurchaseReceipt: Equatable {

    /// The number of items purchased. ASN.1 Field Type 1701.
    /// This value corresponds to the quantity property of the `SKPayment` object stored in the transaction’s payment property.
    public internal(set) var quantity: Int64?

    /// The product identifier of the item that was purchased. ASN.1 Field Type 1702.
    /// This value corresponds to the `productIdentifier` property of the `SKPayment` object stored in the transaction’s `payment` property.
    public internal(set) var productIdentifier: String?

    /// The transaction identifier of the item that was purchased. This value corresponds to the transaction’s `transactionIdentifier` property. ASN.1 Field Type 1703.
    /// - Note: For a transaction that restores a previous transaction, this value is different from the transaction identifier
    ///   of the original purchase transaction. In an auto-renewable subscription receipt, a new value for the transaction identifier
    ///   is generated every time the subscription automatically renews or is restored on a new device.
    public internal(set) var transactionIdentifier: String?

    /// For a **transaction that restores a previous transaction**, the transaction identifier of the original transaction.
    /// **Otherwise**, identical to the transaction identifier.
    /// This value corresponds to the original transaction’s `transactionIdentifier` property. ASN.1 Field Type 1705.
    /// - Note: This value is the same for all receipts that have been generated for a specific subscription.
    ///         This value is useful for relating together multiple iOS 6 style transaction receipts for the same individual customer’s subscription.
    public internal(set) var originalTransactionIdentifier: String?

    /// The date and time that the item was purchased. This value corresponds to the transaction’s `transactionDate` property. ASN.1 Field Type 1704.
    ///
    /// For a **transaction that restores a previous transaction**, the purchase date is the same as the original purchase date.
    /// Use Original Purchase Date to get the date of the original transaction.
    ///
    /// In an **auto-renewable subscription receipt**, the purchase date is the date when the subscription was either purchased or renewed (with or without a lapse).
    ///
    /// For an **automatic renewal** that occurs on the expiration date of the current period, the purchase date is the start date of the next period,
    /// which is identical to the end date of the current period.
    public internal(set) var purchaseDate: Date?

    /// For a **transaction that restores a previous transaction**, the date of the original transaction.
    /// This value corresponds to the original transaction’s `transactionDate` property. ASN.1 Field Type 1706.
    ///
    /// In an **auto-renewable subscription receipt**, this indicates the beginning of the subscription period, even if the subscription has been renewed.
    public internal(set) var originalPurchaseDate: Date?

    /// This key is only present for **auto-renewable subscription receipts**. ASN.1 Field Type 1708.
    ///
    /// Use this value to identify the date when the subscription will renew or expire, to determine if a customer should have access
    /// to content or service. After validating the latest receipt, if the subscription expiration date for the latest renewal
    /// transaction is a past date, it is safe to assume that the subscription has expired.
    public internal(set) var subscriptionExpirationDate: Date?

    /// For a **transaction that was canceled by Apple customer support**, the time and date of the cancellation.
    /// For an **auto-renewable subscription plan that was upgraded**, the time and date of the upgrade transaction.
    /// ASN.1 Field Type 1712.
    /// - Note: A canceled in-app purchase remains in the receipt indefinitely. Only applicable if the refund was for a non-consumable product,
    ///         an auto-renewable subscription, a non-renewing subscription, or for a free subscription.
    public internal(set) var cancellationDate: Date?

    /// The primary key for identifying subscription purchases. ASN.1 Field Type 1711.
    /// This value is a unique ID that identifies purchase events across devices, including subscription renewal purchase events.
    public internal(set) var webOrderLineItemId: Int64?

    /// For documentation see InAppPurchaseReceipt itself.
    public init(quantity: Int64?, productIdentifier: String?, transactionIdentifier: String?, originalTransactionIdentifier: String?, purchaseDate: Date?, originalPurchaseDate: Date?, subscriptionExpirationDate: Date?, cancellationDate: Date?, webOrderLineItemId: Int64?) {
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

// MARK: - CustomStringConvertible

extension InAppPurchaseReceipt: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        let formatter = StringFormatter()
        let props: [(String, String)]  = [
            ("quantity", formatter.format(self.quantity)),
            ("productIdentifier", formatter.format(self.productIdentifier)),
            ("transactionIdentifier", formatter.format(self.transactionIdentifier)),
            ("originalTransactionIdentifier", formatter.format(self.originalTransactionIdentifier)),
            ("purchaseDate", formatter.format(self.purchaseDate)),
            ("originalPurchaseDate", formatter.format(self.originalPurchaseDate)),
            ("subscriptionExpirationDate", formatter.format(self.subscriptionExpirationDate)),
            ("cancellationDate", formatter.format(self.cancellationDate)),
            ("webOrderLineItemId", formatter.format(self.webOrderLineItemId))
        ]
        return "InAppPurchaseReceipt(\n" + formatter.format(props) + "\n)"
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - Custom String Conversion

/// Private Helper for formatting the Receipts descriptions
private struct StringFormatter {

    let fallback = "nil"

    func format(_ inAppPurchaseReceipts: [InAppPurchaseReceipt]?, indentation: String = "    ") -> String {
        guard let inAppPurchaseReceipts = inAppPurchaseReceipts else { return fallback }
        guard !inAppPurchaseReceipts.isEmpty else { return "[]" }

        return "[\n" + inAppPurchaseReceipts.map { $0.description.replacingOccurrences(of: "\n", with: "\n" + indentation) }.joined(separator: ",\n") + "\n]"
    }

    func format(_ pairs: [(String, String)]) -> String {
        return pairs.map { self.format(key: $0, value: $1) }.joined(separator: ",\n")
    }

    func format(_ int: Int64?) -> String {
        guard let int = int else { return fallback }

        return "\(int)"
    }

    func format(key: String, value: String, indentation: String = "    ") -> String {
        return "\(indentation)\(key): \(value)"
    }

    func format(_ data: Data?) -> String {
        guard let data = data else { return fallback }

        return data.base64EncodedString()
    }

    func format(_ date: Date?) -> String {
        guard let date = date else { return fallback }

        return AppReceiptValidator.asn1DateFormatter.string(from: date)
    }

    func format(_ string: String?) -> String {
        return string ?? fallback
    }
}
