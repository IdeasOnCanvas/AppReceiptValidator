//
//  Hekate.swift
//  Hekate iOS
//
//  Created by Hannes Oud on 04.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import Security

public struct Hekate {
    /// Extracts the actual receipt payload data, which is in ASN1-DER binary format, from the PKCS7 receipt container, using CMSDecoder.
    public static func decodeASN1Payload(receiptPKCS7ContainerData data: Data) throws -> Data {
        // Inspired by https://github.com/mbogh/Janitor/blob/master/Janitor/ProvisioningProfile.swift and SSWReceiptValidation.m
        var optionalDecoder: CMSDecoder?
        guard CMSDecoderCreate(&optionalDecoder) == errSecSuccess,
            let decoder = optionalDecoder else {
            throw HekateError.failedToCreateCMSDecoder
        }
        guard data.withUnsafeBytes({ bytes -> OSStatus in
            CMSDecoderUpdateMessage(decoder, bytes, data.count)
        }) == errSecSuccess else {
            throw HekateError.failedToUpdateCMSDecoder
        }
        CMSDecoderFinalizeMessage(decoder)
        var optionalPayloadData: CFData?
        guard CMSDecoderCopyContent(decoder, &optionalPayloadData) == errSecSuccess,
            let payloadData = optionalPayloadData else {
            throw HekateError.failedToCopyDataFromCMSDecoder
        }
        return payloadData as Data
    }
}

public enum HekateError: Int, Error {
    case unknown
    case failedToCreateCMSDecoder
    case failedToUpdateCMSDecoder
    case failedToCopyDataFromCMSDecoder
}
