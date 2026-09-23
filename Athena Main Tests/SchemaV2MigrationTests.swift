//
//  SchemaV2MigrationTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/21/26.
//

import Foundation
import SwiftData
import Testing
@testable import Athena

struct SchemaV2MigrationTests {
    /// Builds a V1 store at a fresh temp URL. Two routine sets (so removing one still
    /// leaves a second set whose exercises would shift position under the old
    /// index-based correlation), covering all four exercise kinds, plus two repeaters
    /// that share a tag but differ in timeOn/timeOff, and a finished session whose
    /// generic exercise snapshot has diverged from the routine's.
    @MainActor
    private func makeV1Store() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "migration-\(UUID().uuidString).store")
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let routine = SchemaV1.Routine(name: "Test Routine", sets: [
            .init(name: "Set A", exercises: [
                .generic(.init(name: "Bench Press", dataType: .repWeight, sets: [.init(num: 5)])),
                .repeater(.init(tag: "Shared Tag", timeOn: 7, timeOff: 3, sets: [.init(numReps: 6)])),
                .repeater(.init(tag: "Shared Tag", timeOn: 5, timeOff: 5, sets: [.init(numReps: 6)])),
            ], restTime: 60, order: .dfs),
            .init(name: "Set B", exercises: [
                .maxHang(.init(tag: "BM Middle", sets: [.init(target: 10)])),
                .campus(.init(type: .maxLadder, sets: [
                    .init(moves: .defined([
                        .init(rung: .full(1), side: .both),
                        .init(rung: .full(5), side: .right),
                    ]))
                ])),
            ], restTime: 90, order: .dfs),
        ])
        context.insert(routine)

        let session = SchemaV1.Session(
            startTime: .now.addingTimeInterval(-3600),
            endTime: .now,
            sets: routine.sets.map({ .init(base: $0) })
        )
        // Diverge the session's generic exercise from the routine's current one —
        // this is the case the migration must link to its own, separate entry.
        session.sets[0].exercises[0] = .generic(.init(
            expected: .init(name: "Bench Press (Diverged)", dataType: .repWeight, sets: [.init(num: 5)]),
            actual: [.init(numReps: 5, weight: 100)]
        ))
        routine.sessions.append(session)
        context.insert(session)
        try context.save()
        return url
    }

    @Test @MainActor func migratesExercisesAndBookkeepingFields() throws {
        let url = try makeV1Store()
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, migrationPlan: AthenaMigrationPlan.self, configurations: [config])
        let context = container.mainContext

        let routines = try context.fetch(FetchDescriptor<Routine>())
        #expect(routines.count == 1)
        let routine = try #require(routines.first)
        #expect(routine.sets.count == 2)
        #expect(routine.sets[0].exercises.count == 3)
        #expect(routine.sets[1].exercises.count == 2)

        // Every routine payload should now be linked.
        for set in routine.sets {
            for exercise in set.exercises {
                #expect(exercise.exerciseID != nil)
            }
        }

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        for set in session.sets {
            for exercise in set.exercises {
                #expect(exercise.exerciseID != nil)
            }
        }

        // The diverged generic session exercise must link to its own entry, distinct
        // from the routine's current "Bench Press" entry.
        #expect(session.sets[0].exercises[0].exerciseID != routine.sets[0].exercises[0].exerciseID)

        // Two repeaters sharing a tag but differing in timeOn/timeOff -> two entries.
        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        let repeaterExercises = allExercises.compactMap { $0 as? RepeaterExercise }
        #expect(repeaterExercises.count == 2)

        // Each entry is the correct subclass: routine's generic + session's diverged
        // generic = 2, plus 1 max hang, 1 campus.
        let genericExercises = allExercises.compactMap { $0 as? GenericExercise }
        let maxHangExercises = allExercises.compactMap { $0 as? MaxHangExercise }
        let campusExercises = allExercises.compactMap { $0 as? CampusLibraryExercise }
        #expect(genericExercises.count == 2)
        #expect(maxHangExercises.count == 1)
        #expect(campusExercises.count == 1)
        #expect(allExercises.count == genericExercises.count + repeaterExercises.count + maxHangExercises.count + campusExercises.count)

        // Bundled bookkeeping fields (step 3).
        #expect(session.routineName == "Test Routine")
        #expect(routine.lastUsedAt != nil)
        #expect(routine.createdAt <= (routine.lastUsedAt ?? .distantFuture))

        // Every pre-V2 session belongs to a single seeded owner athlete, and none of
        // it looks like team data.
        let athletes = try context.fetch(FetchDescriptor<Athlete>())
        #expect(athletes.count == 1)
        let owner = try #require(athletes.first)
        #expect(owner.name == Athlete.defaultName)
        #expect(session.athlete?.uuid == owner.uuid)
        #expect(session.isTeamEntry == false)
        #expect(try context.fetch(FetchDescriptor<TeamSession>()).isEmpty)
    }

    @Test @MainActor func migrationDoesNotRerunOrDuplicateOnReopen() throws {
        let url = try makeV1Store()
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema(SchemaV2.models)
        let firstCount: Int
        let firstAthleteCount: Int
        do {
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, migrationPlan: AthenaMigrationPlan.self, configurations: [config])
            firstCount = try container.mainContext.fetch(FetchDescriptor<Exercise>()).count
            firstAthleteCount = try container.mainContext.fetch(FetchDescriptor<Athlete>()).count
        }

        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, migrationPlan: AthenaMigrationPlan.self, configurations: [config])
        let secondCount = try container.mainContext.fetch(FetchDescriptor<Exercise>()).count
        let secondAthleteCount = try container.mainContext.fetch(FetchDescriptor<Athlete>()).count

        #expect(firstCount == secondCount)
        #expect(firstAthleteCount == 1)
        #expect(secondAthleteCount == 1)
    }

    /// The bug this migration exists partly to fix: `RoutineView.swift:60` used to
    /// correlate a session's exercises to the routine's purely by array position.
    /// Deleting "Set A" from the session (as `SessionHomeView.swift:198` allows
    /// mid-session) shifts "Set B" from session index 1 down to index 0 — the old
    /// code would read `session.sets[1]` (now out of range, or the wrong set if a
    /// third set existed) for anything the routine still has at index 1. Confirms
    /// the exerciseID-based correlation the fix relies on isn't affected by the shift.
    @Test @MainActor func exerciseIDCorrelationSurvivesADeletedSet() throws {
        let url = try makeV1Store()
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, migrationPlan: AthenaMigrationPlan.self, configurations: [config])
        let context = container.mainContext

        let routine = try #require(try context.fetch(FetchDescriptor<Routine>()).first)
        let session = try #require(try context.fetch(FetchDescriptor<Session>()).first)

        // Positive case, before any divergence: every routine exercise has exactly
        // one same-ID match among the session's exercises — except set 0's exercise
        // 0 (generic "Bench Press"), which `makeV1Store` deliberately diverges to
        // its own separate entry; that case is exercised in
        // `migratesExercisesAndBookkeepingFields` instead.
        for (setIndex, set) in routine.sets.enumerated() {
            for (exerciseIndex, payload) in set.exercises.enumerated() {
                guard (setIndex, exerciseIndex) != (0, 0) else { continue }
                let id = try #require(payload.exerciseID)
                let matches = session.sets.flatMap(\.exercises).filter { $0.exerciseID == id }
                #expect(matches.count == 1)
            }
        }

        // Now delete the session's first set (Set A) — Set B's exercises shift from
        // session index 1 to index 0, while the routine still has them at index 1.
        session.sets.removeFirst()

        // Set B's exercises (maxHang, campus) still correlate correctly by ID despite
        // the index shift.
        for payload in routine.sets[1].exercises {
            let id = try #require(payload.exerciseID)
            let match = session.sets.flatMap(\.exercises).first { $0.exerciseID == id }
            #expect(match != nil)
        }

        // Set A's exercises have nothing left to match against — this is the "session
        // diverged, exercise no longer present" case, which should read as "no match"
        // rather than crash or silently pair with an unrelated exercise.
        for payload in routine.sets[0].exercises {
            let id = try #require(payload.exerciseID)
            let match = session.sets.flatMap(\.exercises).first { $0.exerciseID == id }
            #expect(match == nil)
        }
    }
}
