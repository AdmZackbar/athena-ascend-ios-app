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
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test @MainActor func seedsDefaultNameIntoEmptyRoster() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let resolved = CurrentAthlete.resolve(storedID: "", athletes: [], context: context)

        #expect(resolved.name == Athlete.defaultName)
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

    @Test @MainActor func fallsBackToMostRecentlyUsedForAStaleID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let alice = Athlete(name: "Alice", lastUsedAt: .now.addingTimeInterval(-3600))
        let bob = Athlete(name: "Bob", lastUsedAt: .now)
        context.insert(alice)
        context.insert(bob)

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

    @Test @MainActor func routineSessionsScopeCorrectlyPerAthlete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = Routine(name: "Shared Routine")
        context.insert(routine)

        let alice = Athlete(name: "Alice")
        let bob = Athlete(name: "Bob")
        context.insert(alice)
        context.insert(bob)

        let aliceSession = Session(athlete: alice)
        let bobSession = Session(athlete: bob)
        routine.sessions.append(aliceSession)
        routine.sessions.append(bobSession)
        try context.save()

        let aliceOnly = routine.sessions.filter { $0.athlete?.uuid == alice.uuid }
        let bobOnly = routine.sessions.filter { $0.athlete?.uuid == bob.uuid }

        #expect(aliceOnly.count == 1)
        #expect(aliceOnly.first?.persistentModelID == aliceSession.persistentModelID)
        #expect(bobOnly.count == 1)
        #expect(bobOnly.first?.persistentModelID == bobSession.persistentModelID)
    }
}
