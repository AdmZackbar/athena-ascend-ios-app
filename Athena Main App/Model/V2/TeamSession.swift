//
//  TeamSession.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import Foundation
import SwiftData

typealias TeamSession = SchemaV2.TeamSession

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
        /// The shared prescription. Athlete entries are deep copies of this, so their
        /// `sets`/`exercises` indices stay aligned with it by construction — every
        /// structural edit goes through the fan-out helpers in TeamSession+Editing.swift.
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

/// Every structural edit to a team session's exercise plan goes through one of these,
/// so the shared `sets` template and every athlete's `entries` copy stay index-aligned.
extension TeamSession {
    /// Relationship arrays are unordered in SwiftData — always read through this rather
    /// than `entries` directly.
    var sortedEntries: [Session] {
        entries.sorted { ($0.athlete?.name ?? "") < ($1.athlete?.name ?? "") }
    }

    /// Deep-copies the current `sets` template into a new `Session` for `athlete`
    /// (`sets` is built entirely of Codable value types, so the assignment below is
    /// already an independent copy — no manual cloning needed), prefilling body weight
    /// from that athlete's most recent session, same as `MainView`'s routine-start flow.
    @discardableResult
    func addAthlete(_ athlete: Athlete, context: ModelContext) -> Session {
        let recentBodyWeight = athlete.sessions
            .sorted(by: { $0.startTime > $1.startTime })
            .first?.bodyWeight
        let entry = Session(
            sets: sets,
            bodyWeight: recentBodyWeight ?? 160,
            routineName: routineName,
            athlete: athlete
        )
        entry.teamSession = self
        context.insert(entry)
        entries.append(entry)
        athlete.lastUsedAt = .now
        return entry
    }

    func removeEntry(_ entry: Session, context: ModelContext) {
        context.delete(entry)
    }

    func addExercise(_ exercise: Session.Exercise, toSet setIndex: Int) {
        sets[setIndex].exercises.append(exercise)
        for entry in entries {
            entry.sets[setIndex].exercises.append(exercise)
        }
    }

    /// Overwrites every entry's prescription for one exercise to match the template,
    /// preserving each entry's own recorded data. Needed because entries are
    /// independent value copies — editing the template's base config (name, target
    /// sets, etc.) after entries already exist doesn't propagate on its own.
    func syncExercisePrescription(setIndex: Int, exerciseIndex: Int) {
        guard setIndex < sets.count, exerciseIndex < sets[setIndex].exercises.count else { return }
        let template = sets[setIndex].exercises[exerciseIndex]
        for entry in entries {
            guard setIndex < entry.sets.count, exerciseIndex < entry.sets[setIndex].exercises.count else { continue }
            entry.sets[setIndex].exercises[exerciseIndex].updatingPrescription(from: template)
        }
    }

    func removeExercise(at exerciseIndex: Int, inSet setIndex: Int) {
        sets[setIndex].exercises.remove(at: exerciseIndex)
        for entry in entries {
            entry.sets[setIndex].exercises.remove(at: exerciseIndex)
        }
    }

    func addSet(_ set: Session.ExerciseSet) {
        sets.append(set)
        for entry in entries {
            entry.sets.append(set)
        }
    }

    func removeSet(at setIndex: Int) {
        sets.remove(at: setIndex)
        for entry in entries {
            entry.sets.remove(at: setIndex)
        }
    }

    /// Mirrors a manual start-date edit to every entry, so each athlete's own
    /// `Session` stays in sync with the shared parent instead of drifting.
    func updateStartTime(_ date: Date) {
        startTime = date
        for entry in entries {
            entry.startTime = date
        }
    }

    /// Mirrors a manual end-date edit to every entry. Symmetric with `updateStartTime`;
    /// `finish`/`reopen` below cover the automatic finish/reopen flows.
    func updateEndTime(_ date: Date?) {
        endTime = date
        for entry in entries {
            entry.endTime = date
        }
    }

    /// Mirrors `endTime` to every entry and sweeps unlinked exercises into the library —
    /// both the shared template and each athlete's own copy, so entries converge onto
    /// the same library row by identity even though they're independent value copies.
    func finish(at date: Date = .now, context: ModelContext) {
        endTime = date
        ExerciseLibrary.linkUnlinkedExercises(in: &sets, context: context)
        for entry in entries {
            entry.endTime = date
            ExerciseLibrary.linkUnlinkedExercises(in: entry, context: context)
        }
    }

    /// Symmetric with `finish` — clears `endTime` on the parent and every entry so
    /// editing can resume.
    func reopen() {
        endTime = nil
        for entry in entries {
            entry.endTime = nil
        }
    }
}
