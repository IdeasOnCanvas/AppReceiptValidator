//
//  HekateDemoViewModel.swift
//  Hekate Demo iOS
//
//  Created by Hannes Oud on 08.09.17.
//  Copyright © 2017 IdeasOnCanvas GmbH. All rights reserved.
//

import Foundation
import Hekate_iOS

struct HekateDemoViewModel {
    var hasReceipt: Bool {
        return lastReceiptData != nil
    }

    var lastReceiptData: Data?
    var lastValidationResult: ReceiptValidationResult?

    var receiptIsValid: Bool {
        guard let result = lastValidationResult else { return false }
        switch result {
        case .success:
            return true
        default:
            return false
        }
    }

    var descriptionText: String {
        guard let result = lastValidationResult else {
            return "(No result)"
        }
        switch result {
        case .success(let receipt):
            return "Valid\n" + receipt.description
        case .error(let error):
            return "Invalid: \(error)"
        }
    }

    var receiptDataBase64Text: String {
        guard let data = lastReceiptData else {
            return "(no data)"
        }
        return data.base64EncodedString(options: [.lineLength64Characters])
    }

    mutating func update() {
        lastReceiptData = ReceiptOrigin.installedInMainBundle.loadData()
        lastValidationResult = LocalReceiptValidator().validateReceipt(parameters: ReceiptValidationParameters.allSteps)
    }

}
