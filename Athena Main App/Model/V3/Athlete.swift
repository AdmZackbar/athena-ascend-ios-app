//
//  Athlete.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

typealias Athlete = SchemaV3.Athlete

extension SchemaV3 {
    @Model
    final class Athlete {
        /// Unique ID that is used when persisting a data reference outside the DB
        var uuid: UUID = UUID()
        /// The main display name (i.e. nickname)
        var name: String = ""
        var firstName: String? = nil
        var lastName: String? = nil
        var birthDate: Date? = nil
        /// Creation date of the athlete
        var createdAt: Date = Date()
        /// All associated sessions
        var sessions: [Session]! = []
        /// No point in keeping data for a deleted athlete
        @Relationship(deleteRule: .cascade, inverse: \ExerciseData.athlete)
        var data: [ExerciseData]! = []

        init(uuid: UUID = UUID(),
             name: String = "",
             firstName: String? = nil,
             lastName: String? = nil,
             birthDate: Date? = nil,
             createdAt: Date = .now) {
            self.uuid = uuid
            self.name = name
            self.firstName = firstName
            self.lastName = lastName
            self.birthDate = birthDate
            self.createdAt = createdAt
        }
    }
}
