//
//  ReceiptValidator+deviceIdentifier iOS.swift
//  Hekate macOS
//
//  Created by Hannes Oud on 06.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import UIKit

extension ReceiptValidator {
    var deviceIdentifier: UUID? {
        return UIDevice.current.identifierForVendor
    }
}
