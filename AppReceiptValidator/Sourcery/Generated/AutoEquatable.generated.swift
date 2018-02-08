// Generated using Sourcery 0.9.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

private func compareOptionals<T>(lhs: T?, rhs: T?, compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    switch (lhs, rhs) {
    case let (lValue?, rValue?):
        return compare(lValue, rValue)
    case (nil, nil):
        return true
    default:
        return false
    }
}

private func compareArrays<T>(lhs: [T], rhs: [T], compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (idx, lhsItem) in lhs.enumerated() {
        guard compare(lhsItem, rhs[idx]) else { return false }
    }

    return true
}

// MARK: - AutoEquatable for classes, protocols, structs
// MARK: - InAppPurchaseReceipt AutoEquatable
extension InAppPurchaseReceipt: Equatable {}
public func == (lhs: InAppPurchaseReceipt, rhs: InAppPurchaseReceipt) -> Bool {
    guard compareOptionals(lhs: lhs.quantity, rhs: rhs.quantity, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.productIdentifier, rhs: rhs.productIdentifier, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.transactionIdentifier, rhs: rhs.transactionIdentifier, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.originalTransactionIdentifier, rhs: rhs.originalTransactionIdentifier, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.purchaseDate, rhs: rhs.purchaseDate, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.originalPurchaseDate, rhs: rhs.originalPurchaseDate, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.subscriptionExpirationDate, rhs: rhs.subscriptionExpirationDate, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.cancellationDate, rhs: rhs.cancellationDate, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.webOrderLineItemId, rhs: rhs.webOrderLineItemId, compare: ==) else { return false }
    return true
}
// MARK: - Receipt AutoEquatable
extension Receipt: Equatable {}
public func == (lhs: Receipt, rhs: Receipt) -> Bool {
    guard compareOptionals(lhs: lhs.bundleIdentifier, rhs: rhs.bundleIdentifier, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.bundleIdData, rhs: rhs.bundleIdData, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.appVersion, rhs: rhs.appVersion, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.opaqueValue, rhs: rhs.opaqueValue, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.sha1Hash, rhs: rhs.sha1Hash, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.originalAppVersion, rhs: rhs.originalAppVersion, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.receiptCreationDate, rhs: rhs.receiptCreationDate, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.expirationDate, rhs: rhs.expirationDate, compare: ==) else { return false }
    guard lhs.inAppPurchaseReceipts == rhs.inAppPurchaseReceipts else { return false }
    return true
}

// MARK: - AutoEquatable for Enums
