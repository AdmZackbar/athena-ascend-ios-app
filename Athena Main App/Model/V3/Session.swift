//
//  Session.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

typealias Session = SchemaV3.Session

extension SchemaV3 {
    @Model
    final class Session: Hashable {
        var routine: Routine? = nil
        var startTime: Date = Date()
        var endTime: Date? = nil
        var superSets: [Routine.SuperSet] = []
        var notes: String = ""
        var standoutSong: Song? = nil
        /// All associated athletes
        @Relationship(inverse: \Athlete.sessions)
        var athletes: [Athlete]! = []
        /// No point in keeping data for a deleted session
        @Relationship(deleteRule: .cascade, inverse: \ExerciseData.session)
        var data: [ExerciseData]! = []
        
        init(routine: Routine? = nil,
             startTime: Date = .now,
             endTime: Date? = nil,
             superSets: [Routine.SuperSet] = [],
             notes: String = "",
             standoutSong: Song? = nil) {
            self.routine = routine
            self.startTime = startTime
            self.endTime = endTime
            self.superSets = superSets
            self.notes = notes
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
