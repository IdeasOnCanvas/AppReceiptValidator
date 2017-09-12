//
//  StoreKitHelper.swift
//  Hekate Demo iOS
//
//  Created by Hannes Oud on 08.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import StoreKit

@objc
final class StoreKitHelper: NSObject {

    @objc static let shared = StoreKitHelper()

    @objc var refreshCompletedAction: ((NSError?) -> Void)?

    private lazy var delegateHolder: DelegateHolder = {
        let delegateHolder = DelegateHolder()
        delegateHolder.refreshCompletedAction = { [weak self] error in
            self?.refreshCompletedAction?(error)
        }
        return delegateHolder
    }()

    public func refresh() {
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = delegateHolder
        request.start()
    }

    public func logReceipt() {
        print("Local Device ID (GUID):\n" + (UIDevice.current.identifierForVendor?.uuidString ?? "nil"))
        guard let data = receiptData else {
            print("No receipt")
            return
        }
        let base64 = data.base64EncodedString()
        print("ReceiptData:\n" + base64)
    }

    public var receiptData: Data? {
        guard let url = Bundle.main.appStoreReceiptURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        return data
    }
}

/// Encapsules SKRequestDelegate so it is not exposed if not necessary
private final class DelegateHolder: NSObject, SKRequestDelegate {

    var refreshCompletedAction: ((NSError?) -> Void)?

    func requestDidFinish(_ request: SKRequest) {
        print("Fetched receipt.")
        DispatchQueue.main.async {
            self.refreshCompletedAction?(nil)
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("SKReceipt fetching failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.refreshCompletedAction?(error as NSError)
        }
    }
}
