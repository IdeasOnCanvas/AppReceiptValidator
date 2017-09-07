//
//  OpenSSLWrappers.swift
//  Hekate iOS
//
//  Created by Hannes Oud on 07.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation

final class BIOWrapper {
    let bio = BIO_new(BIO_s_mem())

    init(data: Data) {
        data.withUnsafeBytes { pointer -> Void in
            BIO_write(bio, pointer, Int32(data.count))
        }
    }

    init() {}

    deinit {
        BIO_free(bio)
    }
}


final class PKCS7Wrapper {
    var pkcs7: UnsafeMutablePointer<PKCS7>

    init(pkcs7: UnsafeMutablePointer<PKCS7>) {
        self.pkcs7 = pkcs7
    }

    deinit {
        PKCS7_free(pkcs7)
    }
}
