//
//  ReceiptValidator+deviceIdentifier iOS.swift
//  Hekate macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import UIKit

extension ReceiptValidator {
    static var installedDeviceIdentifierData: Data? {
        return UIDevice.current.identifierForVendor?.data
    }

}

private extension UUID {
    var data: Data {
        var rawUUID = uuid
        let data = withUnsafePointer(to: &rawUUID) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: uuid))
        }
        return data
    }
}
