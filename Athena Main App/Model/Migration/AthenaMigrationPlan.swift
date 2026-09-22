//
//  AthenaMigrationPlan.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import Foundation
import SwiftData

enum AthenaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// Additive at the store level (new entities — `Exercise` and its subclasses,
    /// `TeamSession`, `Athlete` — and new scalar/relationship columns; the Codable blob
    /// column is untouched), so this is lightweight-compatible — the custom stage exists
    /// only to backfill the exercise library, the owning `Athlete`, and the
    /// routine/session bookkeeping fields.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            try backfill(context)
        }
    )

    private static func backfill(_ context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let sessions = try context.fetch(FetchDescriptor<Session>())

        var identityMap: [ExerciseIdentity: Exercise] = [:]
        var firstSeen: [ExerciseIdentity: Date] = [:]
        var lastSeen: [ExerciseIdentity: Date] = [:]

        // Exercise createdAt/lastUsedAt are derived from the sessions that actually
        // performed them, not from routines (which have no per-exercise date of
        // their own) — a planned-but-never-run exercise falls back to `.now`/`nil`.
        for session in sessions {
            for set in session.sets {
                for payload in set.exercises {
                    guard let identity = ExerciseIdentity(payload) else { continue }
                    firstSeen[identity] = min(firstSeen[identity] ?? session.startTime, session.startTime)
                    lastSeen[identity] = max(lastSeen[identity] ?? session.startTime, session.startTime)
                }
            }
        }

        func exercise(for identity: ExerciseIdentity) -> Exercise {
            if let existing = identityMap[identity] {
                return existing
            }
            let newExercise = ExerciseLibrary.makeExercise(
                for: identity,
                createdAt: firstSeen[identity] ?? .now,
                lastUsedAt: lastSeen[identity]
            )
            context.insert(newExercise)
            identityMap[identity] = newExercise
            return newExercise
        }

        // Every pre-V2 session belongs to the store's sole owner. Skip creation when
        // there are no sessions — a first-launch seed (CurrentAthlete.resolve) covers
        // that store with the identical name, so there's nothing to backfill here.
        let owner: Athlete? = sessions.isEmpty ? nil : Athlete(
            name: Athlete.defaultName,
            createdAt: sessions.map(\.startTime).min() ?? .now,
            lastUsedAt: sessions.map(\.startTime).max()
        )
        if let owner {
            context.insert(owner)
        }

        for routine in routines {
            for setIndex in routine.sets.indices {
                for exIndex in routine.sets[setIndex].exercises.indices {
                    let payload = routine.sets[setIndex].exercises[exIndex]
                    guard payload.exerciseID == nil, let identity = ExerciseIdentity(payload) else { continue }
                    routine.sets[setIndex].exercises[exIndex].exerciseID = exercise(for: identity).uuid
                }
            }
            let sessionTimes = routine.sessions.map(\.startTime)
            routine.createdAt = sessionTimes.min() ?? .now
            routine.lastUsedAt = sessionTimes.max()
        }

        for session in sessions {
            for setIndex in session.sets.indices {
                for exIndex in session.sets[setIndex].exercises.indices {
                    let payload = session.sets[setIndex].exercises[exIndex]
                    guard payload.exerciseID == nil, let identity = ExerciseIdentity(payload) else { continue }
                    session.sets[setIndex].exercises[exIndex].exerciseID = exercise(for: identity).uuid
                }
            }
            session.routineName = session.routine?.name
            session.athlete = owner
        }

        try context.save()
    }
}
