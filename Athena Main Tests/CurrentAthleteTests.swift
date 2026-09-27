//
//  CurrentAthleteTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/22/26.
//

import Foundation
import SwiftData
import Testing
@testable import Athena

struct CurrentAthleteTests {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test @MainActor func seedsDefaultNameIntoEmptyRoster() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let resolved = CurrentAthlete.resolve(storedID: "", athletes: [], context: context)

        #expect(resolved.name == "Zach")
        #expect(try context.fetch(FetchDescriptor<Athlete>()).count == 1)
    }

    @Test @MainActor func honorsAValidStoredID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let alice = Athlete(name: "Alice")
        let bob = Athlete(name: "Bob")
        context.insert(alice)
        context.insert(bob)

        let resolved = CurrentAthlete.resolve(storedID: bob.uuid.uuidString, athletes: [alice, bob], context: context)

        #expect(resolved.uuid == bob.uuid)
        // No extra athlete should have been seeded.
        #expect(try context.fetch(FetchDescriptor<Athlete>()).count == 2)
    }

    /// V3's `Athlete` has no `lastUsedAt` — recency is derived from the latest
    /// `ExerciseData.session.startTime` across the athlete's own data.
    @Test @MainActor func fallsBackToMostRecentlyUsedForAStaleID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let alice = Athlete(name: "Alice")
        let bob = Athlete(name: "Bob")
        context.insert(alice)
        context.insert(bob)

        let exercise = Exercise(category: .repeater(tag: "HC", timeOn: 7, timeOff: 3))
        context.insert(exercise)

        let aliceSession = Session(startTime: .now.addingTimeInterval(-3600))
        let bobSession = Session(startTime: .now)
        context.insert(aliceSession)
        context.insert(bobSession)

        context.insert(ExerciseData(exercise: exercise, session: aliceSession, athlete: alice, position: .init(setIndex: 0)))
        context.insert(ExerciseData(exercise: exercise, session: bobSession, athlete: bob, position: .init(setIndex: 0)))
        try context.save()

        let resolved = CurrentAthlete.resolve(storedID: UUID().uuidString, athletes: [alice, bob], context: context)

        #expect(resolved.uuid == bob.uuid)
    }

    @Test @MainActor func fallsBackToNameOrderWhenNeitherHasBeenUsed() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let alice = Athlete(name: "Alice")
        let zoe = Athlete(name: "Zoe")
        context.insert(alice)
        context.insert(zoe)

        let resolved = CurrentAthlete.resolve(storedID: "not-a-uuid", athletes: [alice, zoe], context: context)

        #expect(resolved.uuid == alice.uuid)
    }

    /// V3's `Session` has no direct `.athlete` — a session "belongs to" an athlete
    /// only indirectly, through the athletes referenced by its `ExerciseData` rows
    /// (since one V3 session can span several athletes, replacing V2's TeamSession).
    @Test @MainActor func routineSessionsScopeCorrectlyPerAthlete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = Routine(name: "Shared Routine")
        context.insert(routine)

        let alice = Athlete(name: "Alice")
        let bob = Athlete(name: "Bob")
        context.insert(alice)
        context.insert(bob)

        let exercise = Exercise(category: .repeater(tag: "HC", timeOn: 7, timeOff: 3))
        context.insert(exercise)

        let aliceSession = Session(routine: routine)
        let bobSession = Session(routine: routine)
        context.insert(aliceSession)
        context.insert(bobSession)
        routine.sessions.append(aliceSession)
        routine.sessions.append(bobSession)

        context.insert(ExerciseData(exercise: exercise, session: aliceSession, athlete: alice, position: .init(setIndex: 0)))
        context.insert(ExerciseData(exercise: exercise, session: bobSession, athlete: bob, position: .init(setIndex: 0)))
        try context.save()

        let aliceOnly = routine.sessions.filter { session in session.data.contains { $0.athlete?.uuid == alice.uuid } }
        let bobOnly = routine.sessions.filter { session in session.data.contains { $0.athlete?.uuid == bob.uuid } }

        #expect(aliceOnly.count == 1)
        #expect(aliceOnly.first?.persistentModelID == aliceSession.persistentModelID)
        #expect(bobOnly.count == 1)
        #expect(bobOnly.first?.persistentModelID == bobSession.persistentModelID)
    }
}
