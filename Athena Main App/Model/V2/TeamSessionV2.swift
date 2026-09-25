//
//  TeamSession.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import Foundation
import SwiftData

private typealias TeamSession = SchemaV2.TeamSession

extension SchemaV2 {
    @Model
    final class TeamSession {
        var routine: Routine? = nil
        /// Snapshot of the owning routine's name, so the association survives the
        /// `.nullify` delete rule on `Routine.teamSessions`. Prefer `routine?.name` when
        /// available; this is the fallback once the routine is gone.
        var routineName: String? = nil
        var startTime: Date = Date()
        var endTime: Date? = nil
        var notes: String = ""
        /// The shared prescription, kept only so a one-time JSON export can still read
        /// it — the editing/fan-out helpers that used to live here were retired along
        /// with the rest of the live TeamSession UX in V3.
        var sets: [Session.ExerciseSet] = []
        @Relationship(deleteRule: .cascade, inverse: \Session.teamSession)
        var entries: [Session]! = []

        init(routine: Routine? = nil, routineName: String? = nil, startTime: Date = .now, endTime: Date? = nil, notes: String = "", sets: [Session.ExerciseSet] = [], entries: [Session] = []) {
            self.routine = routine
            self.routineName = routineName
            self.startTime = startTime
            self.endTime = endTime
            self.notes = notes
            self.sets = sets
            self.entries = entries
        }
    }
}
