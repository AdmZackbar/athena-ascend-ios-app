//
//  CurrentAthlete.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import Foundation
import SwiftData

/// Resolves and persists which athlete the single-user side of the app (sessions,
/// routine history, charts) currently acts as. There is always exactly one current
/// athlete — no unscoped "all athletes" mode — so every scoped view can assume one exists.
enum CurrentAthlete {
    /// `@AppStorage` key. UI state, not model state — the athlete roster lives in the
    /// store, but which one is "current" is a per-device preference.
    static let storageKey = "CurrentAthleteID"

    /// Resolves the stored UUID against the roster, falling back to the most recently
    /// active athlete, and seeding a default name when the roster is empty. Always
    /// returns an athlete. Callers should write `resolved.uuid` back to the stored ID so
    /// a fallback or seed doesn't need to be re-resolved on every launch.
    ///
    /// V3's `Athlete` has no `lastUsedAt`/`defaultName` (V2 had both) — recency is
    /// derived from the latest session an athlete has logged data in, via their
    /// `ExerciseData` rows, and the default name is inlined here instead.
    @MainActor
    static func resolve(storedID: String, athletes: [Athlete], context: ModelContext) -> Athlete {
        if let uuid = UUID(uuidString: storedID), let match = athletes.first(where: { $0.uuid == uuid }) {
            return match
        }
        func lastActivity(_ athlete: Athlete) -> Date? {
            athlete.data.compactMap { $0.session?.startTime }.max()
        }
        if let mostRecent = athletes.sorted(by: { lhs, rhs in
            switch (lastActivity(lhs), lastActivity(rhs)) {
            case (let l?, let r?): return l > r
            case (nil, nil): return lhs.name < rhs.name
            case (.some, nil): return true
            case (nil, .some): return false
            }
        }).first {
            return mostRecent
        }
        let seeded = Athlete(name: "Zach")
        context.insert(seeded)
        return seeded
    }
}
