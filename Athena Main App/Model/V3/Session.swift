//
//  Session.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

extension SchemaV3 {
    @Model
    final class Session {
        var routine: Routine? = nil
        var startTime: Date = Date()
        var endTime: Date? = nil
        var superSets: [Routine.SuperSet] = []
        var notes: String = ""
        var bodyWeight: Double? = nil
        var standoutSong: Song? = nil
        /// No point in keeping data for a deleted session
        @Relationship(deleteRule: .cascade, inverse: \ExerciseData.session)
        var data: [ExerciseData]! = []
        
        init(routine: Routine? = nil,
             startTime: Date = .now,
             endTime: Date? = nil,
             superSets: [Routine.SuperSet] = [],
             notes: String = "",
             bodyWeight: Double? = nil,
             standoutSong: Song? = nil) {
            self.routine = routine
            self.startTime = startTime
            self.endTime = endTime
            self.superSets = superSets
            self.notes = notes
            self.bodyWeight = bodyWeight
            self.standoutSong = standoutSong
        }

        struct Song: Codable, Hashable {
            var name: String
            var artist: String
            
            init(name: String, artist: String) {
                self.name = name
                self.artist = artist
            }
        }
    }
}
