//
//  DeviceIdentifier+Linux.swift
//  AppReceiptValidator
//
//  Created by Michael Schwarz on 29.01.20.
//

import Foundation

#if os(Linux)


extension AppReceiptValidator.Parameters.DeviceIdentifier {

    /// On linux we use no device identifier data
    static var installedDeviceIdentifierData: Data? {
        return nil
    }
}
#endif
