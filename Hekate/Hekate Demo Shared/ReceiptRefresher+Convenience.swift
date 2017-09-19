//
//  ReceiptRefresher+Convenience.swift
//  Hekate
//
//  Created by Hannes Oud on 19.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import Hekate

// MARK: - Convenience

extension ReceiptRefresher {

    public func logIdentifierAndReceipt() {
        if let deviceIdentifier = LocalReceiptValidator.Parameters.DeviceIdentifier.currentDevice.getData() {
            print("Device Identifier (Base64):\n" + deviceIdentifier.base64EncodedString())
        }
        guard let data = self.receiptData else {
            print("No receipt")
            return
        }
        let base64 = data.base64EncodedString()
        print("ReceiptData (Base64):\n" + base64)
    }

    public var receiptData: Data? {
        guard let url = Bundle.main.appStoreReceiptURL else { return nil }

        return try? Data(contentsOf: url)
    }
}
