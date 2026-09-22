//
//  Athlete.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import Foundation
import SwiftData

typealias Athlete = SchemaV2.Athlete

extension SchemaV2 {
    @Model
    final class Athlete {
        var uuid: UUID = UUID()
        var name: String = ""
        var createdAt: Date = Date()
        var lastUsedAt: Date? = nil
        /// Cascades: a session with no athlete is meaningless, and would be unreachable
        /// anyway once every view filters by the current athlete. Unlike `Routine.sessions`
        /// (`.nullify` + a `routineName` snapshot), there is nothing worth keeping here.
        @Relationship(deleteRule: .cascade, inverse: \Session.athlete)
        var sessions: [Session]! = []

        init(name: String = "", createdAt: Date = .now, lastUsedAt: Date? = nil) {
            self.name = name
            self.createdAt = createdAt
            self.lastUsedAt = lastUsedAt
        }

        /// The name given to the store owner by both the V1→V2 backfill and the
        /// first-launch seed, so the two paths can never diverge.
        static let defaultName = "Zach Wassynger"
    }
}
