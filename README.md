# Hekate

An iOS and macOS project intended for dealing with App Store receipts.
[Hekate](https://en.wikipedia.org/wiki/Hecate) is the goddess of magic, crossroads, ghosts, and necromancy.

## Resources

- [Apple guide](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html)
- [objc.io guide](https://www.objc.io/issues/17-security/receipt-validation/)
- [Andrew Bancroft complete guide](https://www.andrewcbancroft.com/2017/08/01/local-receipt-validation-swift-start-finish/), or directly [ReceiptValidator.swift](https://github.com/andrewcbancroft/SwiftyLocalReceiptValidator/blob/master/ReceiptValidator.swift)
- [OpenSSL-Universal Pod](https://github.com/krzyzanowskim/OpenSSL)
- WWDC 2013 - 308 Using Receipts to Protect Your Digital Sales
- WWDC 2014 - 305 Preventing Unauthorized Purchases with Receipts
- WWDC 2016 - 702 Using Store Kit for In-App Purchases with Swift 3
- WWDC 2017 - 305 Advanced StoreKit

## Other Options

#### Alternatives to PKCS7 of OpenSSL
- `Security.framework` - `CMSDecoder` for PKCS7 interaction only available on macOS
- `BoringSSL` instead of OpenSSL, Pod, only available on iOS

#### Alternatives to ASN1 of OpenSSL
- [decoding-asn1-der-sequences-in-swift](http://nspasteboard.com/2016/10/23/decoding-asn1-der-sequences-in-swift/) implemented [here](https://gist.github.com/Jugale/2daaec0715d4f6d7347534d42bfa7110)
- [Asn1Parser.swift](https://github.com/TakeScoop/SwiftyRSA/blob/03250be7319d8c54159234e5258ead395ea4de4c/SwiftyRSA/Asn1Parser.swift)


