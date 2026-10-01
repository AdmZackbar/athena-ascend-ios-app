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
        /// Stable, persistent identity of this session. A session's persistentModelID
        /// (the default key used in hashes and equals) changes once it's actually
        /// saved to the DB, which is fatal if the session is used as a dictionary key -
        /// so a stable UUID is assigned at creation instead.
        private(set) var uuid: UUID = UUID()

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
            self.uuid = UUID()
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
        
        // Override hash and equals to make it more stable
        // The persistent ID can change after insertion, which makes it
        // very unreliable as a hash key source
        // UUIDs should be unique, so only it needs to be used
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }
        
        static func == (lhs: Session, rhs: Session) -> Bool {
            lhs.uuid == rhs.uuid
        }

        /// Adds the given athletes to the session, creating one `ExerciseData` entry per
        /// existing exercise slot so every new athlete gets a matching row - falling back
        /// to the routine for slots no athlete has data for yet, and preferring existing
        /// data (which may have diverged from the routine) otherwise.
        func addAthletes(_ newAthletes: [Athlete]) {
            athletes += newAthletes
            var templates: [ExerciseData.Position: (exercise: Exercise, expectedData: [ExerciseData.DataSet])] = [:]
            if let routine {
                for d in routine.data {
                    templates[d.position] = (d.exercise, d.expectedData)
                }
            }
            for d in data {
                templates[d.position] = (d.exercise, d.expectedData)
            }
            for athlete in newAthletes {
                data += templates.map { position, template in
                    ExerciseData(exercise: template.exercise, session: self, athlete: athlete, position: position, expectedData: template.expectedData)
                }
            }
        }
    }
}
