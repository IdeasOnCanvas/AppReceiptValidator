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
