//
//  Item.swift
//  LiveCoach
//
//  Created by Martin Weber - dotSource SE on 16.10.26.
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
