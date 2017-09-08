//
//  StoreKitHelper.swift
//  Hekate Demo iOS
//
//  Created by Hannes Oud on 08.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import StoreKit

final class StoreKitHelper: NSObject {
    var refreshCompletedAction: ((Error?) -> Void)?

    func refresh() {
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        request.start()
    }
}

extension StoreKitHelper: SKRequestDelegate {
    func requestDidFinish(_ request: SKRequest) {
        print("SKReceiptRefreshRequest finished")
        DispatchQueue.main.async {
            self.refreshCompletedAction?(nil)
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("SKReceiptRefreshRequest failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.refreshCompletedAction?(error)
        }
    }
}
