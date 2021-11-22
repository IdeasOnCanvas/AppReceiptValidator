# AppReceiptValidator

[![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
![Platforms iOS, macOS](https://img.shields.io/badge/Platform-iOS%20|%20macOS%20|%20tvOS-blue.svg "Platforms iOS, macOS, tvOS")
![Language Swift](https://img.shields.io/badge/Language-Swift%205.0-orange.svg "Swift 5.0")
[![License Apache 2.0](https://img.shields.io/badge/License-Apache%202.0%20|%20OpenSSL%20-aaaaff.svg "License")](LICENSE)
[![Build Status](https://travis-ci.org/IdeasOnCanvas/AppReceiptValidator.svg?branch=master)](https://travis-ci.org/IdeasOnCanvas/AppReceiptValidator)
[![Twitter: @hannesoid](https://img.shields.io/badge/Twitter-@hannesoid-red.svg?style=flat)](https://twitter.com/hannesoid)


An iOS and macOS library intended for dealing with App Store receipts, offering basic local retrieval, validation and parsing of receipt files.

Provides Demo Apps on iOS and macOS to inspect receipt files.

## Integration with SPM

To install using Swift Package Manager, add this to the `dependencies:` section in your Package.swift file:
```swift
.package(url: "https://github.com/IdeasOnCanvas/AppReceiptValidator.git", from: "1.0.0"),
```

Earlier carthage support has been removed, in order to reduce maintainance work. SPM is the preferred mechanism now. For legacy versions, which support carthage integration you can refer to tags < 1.0.0. For a version supporting integration via xcframework refer to branch `experiment/openSSLXCFramework`.

## Usage in Code

Apple advises to write your own code for receipt validation. Anyways this repo might be a starting point for you, or be used as a dependency at your own risk, or might just be helpful for you to inspect receipts.

### Just parsing a receipt

```swift
let receiptValidator = AppReceiptValidator()

let installedReceipt = receiptValidator.parseReceipt(origin: .installedInMainBundle)

let customReceipt = receiptValidator.parseReceipt(origin: .data(dataFromSomewhere))
```

Result may look like this:

```
Receipt(
    bundleIdentifier: com.some.bundleidentifier,
    bundleIdData: BVWNwKILNEWPOJWELKWEF=,
    appVersion: 1,
    opaqueValue: xN1AVLC2Gge+tYX2qELgSA==,
    sha1Hash: LgoRW+rBxXAjpb03NJlVqa2Z200=,
    originalAppVersion: 1.0,
    receiptCreationDate: 2015-08-13T07:50:46Z,
    expirationDate: nil,
    inAppPurchaseReceipts: [
    InAppPurchaseReceipt(
        quantity: nil,
        productIdentifier: consumable,
        transactionIdentifier: 1000000166865231,
        originalTransactionIdentifier: 1000000166865231,
        purchaseDate: 2015-08-07T20:37:55Z,
        originalPurchaseDate: 2015-08-07T20:37:55Z,
        subscriptionExpirationDate: nil,
        cancellationDate: nil,
        webOrderLineItemId: nil
    ),
    InAppPurchaseReceipt(
        quantity: nil,
        productIdentifier: monthly,
        transactionIdentifier: 1000000166965150,
        originalTransactionIdentifier: 1000000166965150,
        purchaseDate: 2015-08-10T06:49:32Z,
        originalPurchaseDate: 2015-08-10T06:49:33Z,
        subscriptionExpirationDate: 2015-08-10T06:54:32Z,
        cancellationDate: nil,
        webOrderLineItemId: nil
    )
    ]
)
```

**Receipt** is *Equatable*, so you can do comparisons in Unit Tests.
There are also some opt-in unofficial attributes, but this is experimental and should not be used in production.

### Validating a receipt's signature and hash

```swift
// Full validation of signature and hash based on installed receipt
let result = receiptValidator.validateReceipt()

switch result {
    case .success(let receipt, let receiptData, let deviceIdentifier):
    print("receipt validated and parsed: \(receipt)")
    print("the retrieved receipt file's data was: \(receiptData.count) bytes")
    print("the retrieved deviceIdentifier is: \(deviceIdentifier)")
    case .error(let validationError, let receiptData, let deviceIdentifier):
    print("receipt not valid: \(validationError)")
    // receiptData and deviceIdentifier are optional and might still have been retrieved
}
```

### Customize validation dependencies or steps

Take `AppReceiptValidator.Parameters.default` and customize it, then pass it to `validateReceipt(parameters:)`, like so:

```swift
// Customizing validation parameters with configuration block, base on .default
let parameters = AppReceiptValidator.Parameters.default.with {
    $0.receiptOrigin = .data(myData)
    $0.shouldValidateSignaturePresence = false // skip signature presence validation
    $0.signatureValidation = .skip // skip signature authenticity validation
    $0.shouldValidateHash = false // skip hash validation
    $0.deviceIdentifier = .data(myCustomDeviceIdentifierData)

    // validate some string properties, this can also be done 
    // independently with validateProperties(receipt:, validations:)
    // There are also shorthands for comparing with main bundle's 
    // info.plist, e.g. bundleIdMatchingMainBundle and friends.
    // Note that appVersion meaning is platform specific.
    $0.propertyValidations = [
        .string(\.bundleIdentifier, expected: "my.bundle.identifier"),
        .string(\.appVersion, expected: "123"),
        .string(\.originalAppVersion, expected: "1")
    ]
}

let result = AppReceiptValidator().validate(parameters: parameters)

// switch on result
```

## Demo Apps

Paste base64-encoded receipt data into the macOS or iOS demo app to see what AppReceiptValidator parses from it. The macOS App supports:

- Drag n Drop an application or its receipt file onto it to inspect

![Drag n Drop Applications on macOS](./demo-app.gif)

## StoreKit Hints

This framework currently doesn't deal with StoreKit. But the receipt file might not exist at all. What now?

If you have no receipt (happens in development builds) or your receipt is invalid, see resources on how to update it using StoreKit functionality. Known caveats:

- `SKPaymentQueue.restoreCompletedTransactions()` might not update the the receipt, especially if no IAPs were made or the receipt is valid - [openradar](https://openradar.appspot.com/radar?id=6080726030090240)
- `exit(173)` only works on macOS
- Make some kind of purchase, i.e. App Store transaction, to update it
- Each mechanism of receipt refresh will be intrusive to the user, mostly asking for AppleID password.
- Apple advises to write your own code for receipt validation, and build and link OpenSSL statically to your app target. Anyways this repo might be a starting point for you.
- Also have a look at [SwiftyStoreKit](https://github.com/bizz84/SwiftyStoreKit) for dealing with StoreKit, interpretation of receipts, server-verification, and more

## How it Works

### AppReceiptValidator Uses 

- [ASN1Decoder](https://github.com/filom/ASN1Decoder) package for decoding the PKCS#7 and ASN1 receipt components
- [Swift-Crypto](https://github.com/apple/swift-crypto) for hash & signature verification, using the BoringSSL shims parts of it

##### Alternative: StoreKit2
Apple's Storekit2 can provide some of similar functionality, while offering different levels of control and has higher os requirements.

##### Alternative: Validation Server to Server
An app can send its receipt file to a backend from where Apples receipt API can be called. See Resources.

Advantages doing it locally:

- Works offline
- Validation mechanisms can be adjusted
- Can be parsed without validation

## Resources

- [Apple guide](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html)
- [objc.io guide](https://www.objc.io/issues/17-security/receipt-validation/)
- [Andrew Bancroft complete guide](https://www.andrewcbancroft.com/2017/08/01/local-receipt-validation-swift-start-finish/), or directly [ReceiptValidator.swift](https://github.com/andrewcbancroft/SwiftyAppReceiptValidator/blob/master/ReceiptValidator.swift). This is what the AppReceiptValidator implementation was _originally_ based on, thanks Andrew!
- WWDC 2013 - 308 Using Receipts to Protect Your Digital Sales
- WWDC 2014 - 305 Preventing Unauthorized Purchases with Receipts
- WWDC 2016 - 702 Using Store Kit for In-App Purchases with Swift 3
- **WWDC 2017 - 304 What's New in Storekit**
- **WWDC 2017 - 305 Advanced StoreKit**: Receipt checking and it's internals
- [Storekit2 announcement] (https://developer.apple.com/news/?id=1mmydqta)
- [SwiftyStoreKit](https://github.com/bizz84/SwiftyStoreKit)
- [AppStoreReceiptChecker](https://github.com/delicious-monster/AppStoreReceiptChecker) - macOS, uses CMSDecoder and a Swift ASN1 Implementation

## Updating Apple Root Certificate
For convenience, AppReceiptValidator contains a copy of apples root certificate to validate the signature against. If uncomfortable with this, you can specify your own by changing the parameters like this:
```swift
let myParameters = AppReceiptValidator.Parameters.default.with {
    $0.signatureValidation = .shouldValidate(.data(myAppleRootCertData))
}
```
## Credits
AppReceiptValidator is brought to you by [IdeasOnCanvas GmbH](https://ideasoncanvas.com), the creator of [MindNode for iOS, macOS & watchOS](https://mindnode.com).
