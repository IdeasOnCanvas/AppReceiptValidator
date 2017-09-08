//
//  ReceiptDeviceIdentifier+deviceIdentifier iOS.swift
//  Hekate macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import UIKit

extension ReceiptDeviceIdentifier {
    /// On iOS this is the UIDevice's identifierForVendor UUID data
    static var installedDeviceIdentifierData: Data? {
        return UIDevice.current.identifierForVendor?.data
    }
}

private extension UUID {
    /// Get's the raw bytes of a Foundation UUID
    var data: Data {
        var rawUUID = self.uuid
        let data = withUnsafePointer(to: &rawUUID) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: uuid))
        }
        return data
    }
}
