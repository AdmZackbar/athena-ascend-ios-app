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
        /// Unique ID that is used when persisting a data reference outside the DB
        var uuid: UUID = UUID()
        /// The main display name (i.e. nickname)
        var name: String = ""
        var firstName: String? = nil
        var lastName: String? = nil
        /// Creation date of the athlete
        var createdAt: Date = Date()
        /// The date that this athlete was last referenced in a session
        var lastUsedAt: Date? = nil
        // No need to keep sessions of the athlete if deleted
        @Relationship(deleteRule: .cascade, inverse: \Session.athlete)
        var sessions: [Session]! = []

        init(name: String = "",
             firstName: String? = nil,
             lastName: String? = nil,
             createdAt: Date = .now,
             lastUsedAt: Date? = nil) {
            self.name = name
            self.firstName = firstName
            self.lastName = lastName
            self.createdAt = createdAt
            self.lastUsedAt = lastUsedAt
        }

        /// The name given to the store owner by both the V1→V2 backfill and the
        /// first-launch seed, so the two paths can never diverge.
        static let defaultName = "Zach Wassynger"
    }
}
