//
//  ReceiptDeviceIdentifier+deviceIdentifier macOS.swift
//  Hekate macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import IOKit

extension ReceiptDeviceIdentifier {

    /// On mac this is the primary network interface's MAC Adress as bytes
    static var installedDeviceIdentifierData: Data? {
        return getPrimaryNetworkMACAddress()?.data
    }

    /// Finds the MAC Address of the primary network interface.
    /// Original implementation https://gist.github.com/mminer/82975d3781e2f42fc644d7fbfbf4f905
    ///
    /// - Returns: The MAC Address as Data and String representation
    private static func getPrimaryNetworkMACAddress() -> (data: Data, addressString: String)? {
        let matching = IOServiceMatching("IOEthernetInterface") as NSMutableDictionary
        matching[kIOPropertyMatchKey] = ["IOPrimaryInterface": true]
        var servicesIterator: io_iterator_t = 0
        defer { IOObjectRelease(servicesIterator) }

        guard IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &servicesIterator) == KERN_SUCCESS else { return nil }

        var address: [UInt8] = [0, 0, 0, 0, 0, 0]
        var service = IOIteratorNext(servicesIterator)

        while service != 0 {
            var controllerService: io_object_t = 0

            defer {
                IOObjectRelease(service)
                IOObjectRelease(controllerService)
                service = IOIteratorNext(servicesIterator)
            }

            guard IORegistryEntryGetParentEntry(service, "IOService", &controllerService) == KERN_SUCCESS else { continue }

            let ref = IORegistryEntryCreateCFProperty(controllerService, "IOMACAddress" as CFString, kCFAllocatorDefault, 0)

            guard let data = ref?.takeRetainedValue() as? Data else { continue }

            data.copyBytes(to: &address, count: address.count)
        }

        let addressString = address
            .map { String(format: "%02x", $0) }
            .joined(separator: ":")

        return (data: Data(bytes: address), addressString: addressString)
    }
}
