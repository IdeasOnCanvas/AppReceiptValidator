//
//  DeviceIdentifier+installedDeviceIdentifier macOS.swift
//  AppReceiptValidator macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

#if canImport(IOKit)
import Foundation
import IOKit

extension AppReceiptValidator.Parameters.DeviceIdentifier {

    /// On mac this is the primary network interface's MAC Adress as bytes
    static var installedDeviceIdentifierData: Data? {
        return getPrimaryNetworkMACAddress()?.data
    }

    /// Finds the MAC Address of the primary network interface.
    /// Original implementation https://gist.github.com/mminer/82975d3781e2f42fc644d7fbfbf4f905
    ///
    /// - Returns: The MAC Address as Data and String representation
    public static func getPrimaryNetworkMACAddress() -> (data: Data, addressString: String)? {
        guard let data = copyMACAddress() else { return nil }

        var address: [UInt8] = [0, 0, 0, 0, 0, 0]
        data.copyBytes(to: &address, count: address.count)


        let addressString = address
            .map { String(format: "%02x", $0) }
            .joined(separator: ":")

        return (data: Data(address), addressString: addressString)
    }
}

private extension AppReceiptValidator.Parameters.DeviceIdentifier {

    // Returns an object with a +1 retain count; the caller must release.
    static func io_service(named name: String, wantBuiltIn: Bool) -> io_service_t? {
        let default_port = kIOMasterPortDefault
        var iterator = io_iterator_t()
        defer {
            if iterator != IO_OBJECT_NULL {
                IOObjectRelease(iterator)
            }
        }

        guard let matchingDict = IOBSDNameMatching(default_port, 0, name),
              IOServiceGetMatchingServices(default_port,
                                           matchingDict as CFDictionary,
                                           &iterator) == KERN_SUCCESS,
              iterator != IO_OBJECT_NULL
        else {
            return nil
        }

        var candidate = IOIteratorNext(iterator)
        while candidate != IO_OBJECT_NULL {
            if let cftype = IORegistryEntryCreateCFProperty(candidate,
                                                            "IOBuiltin" as CFString,
                                                            kCFAllocatorDefault,
                                                            0) {
                let isBuiltIn = cftype.takeRetainedValue() as! CFBoolean
                if wantBuiltIn == CFBooleanGetValue(isBuiltIn) {
                    return candidate
                }
            }

            IOObjectRelease(candidate)
            candidate = IOIteratorNext(iterator)
        }

        return nil
    }

    static func copyMACAddress() -> Data? {
        // Prefer built-in network interfaces.
        // For example, an external Ethernet adaptor could displace
        // the built-in Wi-Fi as en0.
        guard let service = io_service(named: "en0", wantBuiltIn: true)
                ?? io_service(named: "en1", wantBuiltIn: true)
                ?? io_service(named: "en0", wantBuiltIn: false)
        else { return nil }
        defer { IOObjectRelease(service) }

        if let cftype = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "IOMACAddress" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)) {
            return (cftype as! Data)
        }

        return nil
    }
}
#endif
