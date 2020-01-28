//
//  DeviceIdentifier+installedDeviceIdentifier_iOS.swift
//  AppReceiptValidator macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import UIKit

extension AppReceiptValidator.Parameters.DeviceIdentifier {

    /// On iOS this is the UIDevice's identifierForVendor UUID data
    static var installedDeviceIdentifierData: Data? {
        return UIDevice.current.identifierForVendor?.data
    }
}
