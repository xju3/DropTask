//
//  Item.swift
//  DropTask
//
//  Created by Xiangjun Ju on 2026-05-28 23:09.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
