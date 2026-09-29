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
        /// Added as means of an ACTUAL persistent ID that is stable
        /// If a session is added its persistentId (the key used in hashes and equals)
        /// will changed once it is actually saved to the DB. This results in a fatal
        /// error if the session is used as a key in a dictionary, since its key changes.
        /// I don't want to make a schema change to add this, so I'm keeping it
        /// transient for now. If this needs to be persistent across app instances,
        /// then a schema change will be needed.
        @Transient let uuid = UUID()
        
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
    }
}
