//
//  DropAcceptingTextView.swift
//  AppReceiptValidator Demo macOS
//
//  Created by Hannes Oud on 13.02.18.
//  Copyright © 2018 IdeasOnCanvas GmbH. All rights reserved.
//

import Cocoa

private enum AttachmentDropError: Error {
    case noAttachments
}

final class DropAcceptingTextView: NSTextView {

    var handleDroppedFile: ((URL) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        var draggedTypes = self.registeredDraggedTypes
        draggedTypes.insert(makeFileNameType(), at: 0)
        self.registerForDraggedTypes(draggedTypes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.fileURLs.isEmpty == false {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let fileURL = sender.fileURLs.first  {
            self.handleDroppedFile?(fileURL)
            return true
        }
        return super.performDragOperation(sender)
    }
}

fileprivate extension NSDraggingInfo {

    var fileURLs: [URL] {
        let asStrings = self.draggingPasteboard().propertyList(forType: makeFileNameType()) as? [String] ?? []
        return asStrings.map { URL(fileURLWithPath: $0) }
    }
}

private func makeFileNameType() -> NSPasteboard.PasteboardType {
    // in 10.13 there is more modern NSPasteboard.PasteboardType.fileURL or previously
    // NSPasteboard.PasteboardType("public.file-url"), but so far couldn't find a way
    // to read them from draggingPasteboard()
    return NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
}
