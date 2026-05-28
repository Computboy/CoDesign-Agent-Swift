//
//  Item.swift
//  CoDesign-Agent
//
//  Created by mac on 2026/5/28.
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
