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
    ///
    /// Note: this uses `getPrimaryNetworkMACAddress` but it may be advisable to try to use `getLegacyPrimaryNetworkMACAddress` in case of validation failure
    static var installedDeviceIdentifierData: Data? {
        return getPrimaryNetworkMACAddress()?.data
    }

    /// Finds the MAC Address of the primary network interface.
    /// Based on: https://developer.apple.com/documentation/appstorereceipts/validating_receipts_on_the_device
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

    /// Legacy Style of getting primary network MAC Address.
    /// This is the way we retrieved the MAC Address before https://github.com/IdeasOnCanvas/AppReceiptValidator/pull/79
    ///
    /// Finds the MAC Address of the primary network interface.
    /// Original implementation https://gist.github.com/mminer/82975d3781e2f42fc644d7fbfbf4f905
    ///
    /// - Returns: The MAC Address as Data and String representation
    public static func getLegacyPrimaryNetworkMACAddress() -> (data: Data, addressString: String)? {
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

        return (data: Data(address), addressString: addressString)
    }
}

private extension AppReceiptValidator.Parameters.DeviceIdentifier {

    // Returns an object with a +1 retain count; the caller must release.
    static func io_service(named name: String, requireBuiltIn: Bool) -> io_service_t? {
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
            guard let cftype = IORegistryEntryCreateCFProperty(
                candidate,
                "IOBuiltin" as CFString,
                kCFAllocatorDefault,
                0
            ) else {
                return candidate
            }

            // the following behaviour is modelled after https://github.com/IdeasOnCanvas/AppReceiptValidator/issues/83#issuecomment-1966283436
            let isBuiltIn = cftype.takeRetainedValue() as! CFBoolean
            if CFBooleanGetValue(isBuiltIn) == true {
                // built-in interfaces are always accepted
                return candidate
            } else if requireBuiltIn == false {
                // if built-in isn't required, any candidate will be accepted
                return candidate
            } else {
              // This one is not built in but we would have wanted built in,
              // …keep iterating looking for further interfaces that match what we are looking for.
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

        // Apple sample code uses `requireBuiltIn: true` for en1, but as discussed in  https://github.com/IdeasOnCanvas/AppReceiptValidator/issues/83#issuecomment-1966283436 their internal implementations seem to do `requireBuiltIn: false`
        guard let service = io_service(named: "en0", requireBuiltIn: true)
                ?? io_service(named: "en1", requireBuiltIn: false)
                ?? io_service(named: "en0", requireBuiltIn: false)
        else { return nil }
        defer { IOObjectRelease(service) }

        if let cftype = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "IOMACAddress" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)) {
            return (cftype as! Data)
        }

        return nil
    }
}
#endif
