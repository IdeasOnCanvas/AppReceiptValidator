//
//  ReceiptRefresher.swift
//  Hekate
//
//  Created by Hannes Oud on 19.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import StoreKit

@objc
class ReceiptRefresher: NSObject {

    /// Refreshes the app store receipt using `SKReceiptRefreshRequest(receiptProperties: nil)`
    /// - Parameters:
    ///   - queue: Queue on which the completion is called, defaults to main queue.
    ///   - completion: Called after the refresh has completed, gets passed the error on failure.
    /// - Note: An iTunes Authentication alert will be presented by the system.
    public func refreshReceipt(queue: DispatchQueue = .main, completion: ((NSError?) -> Void)?) {
        let handler = RefreshCompletionHandler(queue: queue, completion: completion)
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = handler
        request.start()
    }
}

/// Encapsules SKRequestDelegate so it is not exposed at all.
///
/// - Note: Retains itself until the delegate is called.
private final class RefreshCompletionHandler: NSObject, SKRequestDelegate {

    private let completion: ((NSError?) -> Void)?
    private var retainedSelf: RefreshCompletionHandler?
    private let queue: DispatchQueue

    init(queue: DispatchQueue, completion: ((NSError?) -> Void)?) {
        self.completion = completion
        self.queue = queue
        super.init()
        self.retainedSelf = self
    }

    func requestDidFinish(_ request: SKRequest) {
        self.queue.async {
            self.completion?(nil)
            self.retainedSelf = nil
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        self.queue.async {
            self.completion?(error as NSError)
            self.retainedSelf = nil
        }
    }
}
