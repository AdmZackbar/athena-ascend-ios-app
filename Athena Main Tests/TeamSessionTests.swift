//
//  TeamSessionTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/22/26.
//

import Foundation
import SwiftData
import Testing
@testable import Athena

struct TeamSessionTests {
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private func makeRoutine(in context: ModelContext) -> Routine {
        let routine = Routine(name: "Test Routine", sets: [
            .init(name: "Set A", exercises: [
                .generic(.init(name: "Bench Press", dataType: .repWeight, sets: [.init(num: 5)]))
            ], restTime: 60, order: .dfs)
        ])
        context.insert(routine)
        return routine
    }

    @Test @MainActor func addAthleteDeepCopiesTemplate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = makeRoutine(in: context)
        let teamSession = TeamSession(sets: routine.sets.map(Session.ExerciseSet.init))
        context.insert(teamSession)

        let alice = Athlete(name: "Alice")
        let bob = Athlete(name: "Bob")
        context.insert(alice)
        context.insert(bob)

        let aliceEntry = teamSession.addAthlete(alice, context: context)
        let bobEntry = teamSession.addAthlete(bob, context: context)

        // Mutate Alice's entry only.
        if case .generic(var d) = aliceEntry.sets[0].exercises[0] {
            d.actual = [.init(numReps: 5, weight: 100)]
            aliceEntry.sets[0].exercises[0] = .generic(d)
        } else {
            Issue.record("Expected generic exercise")
        }

        // Bob's copy, and the template, are untouched.
        if case .generic(let d) = bobEntry.sets[0].exercises[0] {
            #expect(d.actual.isEmpty)
        } else {
            Issue.record("Expected generic exercise")
        }
        if case .generic(let d) = teamSession.sets[0].exercises[0] {
            #expect(d.actual.isEmpty)
        } else {
            Issue.record("Expected generic exercise")
        }
    }

    @Test @MainActor func structuralEditsStayIndexAligned() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = makeRoutine(in: context)
        let teamSession = TeamSession(sets: routine.sets.map(Session.ExerciseSet.init))
        context.insert(teamSession)
        let alice = Athlete(name: "Alice")
        context.insert(alice)
        let entry = teamSession.addAthlete(alice, context: context)

        teamSession.addExercise(.repeater(.init(expected: .init(tag: "New Hold"))), toSet: 0)
        #expect(teamSession.sets[0].exercises.count == 2)
        #expect(entry.sets[0].exercises.count == 2)

        teamSession.removeExercise(at: 0, inSet: 0)
        #expect(teamSession.sets[0].exercises.count == 1)
        #expect(entry.sets[0].exercises.count == 1)
        if case .repeater = teamSession.sets[0].exercises[0] {} else {
            Issue.record("Expected repeater to remain after removing index 0")
        }

        teamSession.addSet(.init(base: .init(name: "Set B")))
        #expect(teamSession.sets.count == 2)
        #expect(entry.sets.count == 2)

        teamSession.removeSet(at: 0)
        #expect(teamSession.sets.count == 1)
        #expect(entry.sets.count == 1)
        #expect(teamSession.sets[0].name == "Set B")
        #expect(entry.sets[0].name == "Set B")
    }

    @Test @MainActor func deletingTeamSessionCascadesEntriesButNotAthletes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = makeRoutine(in: context)
        let teamSession = TeamSession(sets: routine.sets.map(Session.ExerciseSet.init))
        context.insert(teamSession)
        let alice = Athlete(name: "Alice")
        context.insert(alice)
        _ = teamSession.addAthlete(alice, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Session>()).count == 1)

        context.delete(teamSession)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Athlete>()).count == 1)
    }

    @Test @MainActor func deletingAthleteCascadesOnlyTheirEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = makeRoutine(in: context)
        let teamSession = TeamSession(sets: routine.sets.map(Session.ExerciseSet.init))
        context.insert(teamSession)
        let alice = Athlete(name: "Alice")
        let bob = Athlete(name: "Bob")
        context.insert(alice)
        context.insert(bob)
        _ = teamSession.addAthlete(alice, context: context)
        let bobEntry = teamSession.addAthlete(bob, context: context)
        try context.save()

        context.delete(alice)
        try context.save()

        // Bob's entry, and the team session itself, survive.
        let remainingSessions = try context.fetch(FetchDescriptor<Session>())
        #expect(remainingSessions.count == 1)
        #expect(remainingSessions.first?.persistentModelID == bobEntry.persistentModelID)
        #expect(try context.fetch(FetchDescriptor<TeamSession>()).count == 1)
    }

    @Test @MainActor func finishPropagatesEndTimeAndLinksLibrary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = makeRoutine(in: context)
        let teamSession = TeamSession(sets: routine.sets.map(Session.ExerciseSet.init))
        context.insert(teamSession)
        let alice = Athlete(name: "Alice")
        context.insert(alice)
        let entry = teamSession.addAthlete(alice, context: context)

        // A brand-new, unlinked exercise added mid-session.
        teamSession.addExercise(.repeater(.init(expected: .init(tag: "New Hold"))), toSet: 0)

        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 0)

        let finishDate = Date.now
        teamSession.finish(at: finishDate, context: context)

        #expect(teamSession.endTime == finishDate)
        #expect(entry.endTime == finishDate)
        // "Bench Press" (from the routine template) + "New Hold" (added mid-session),
        // each appearing in both the template and the entry, should converge onto
        // exactly one library row apiece rather than duplicating per container.
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 2)
    }

    @Test @MainActor func teamEntriesAreNeverInRoutineSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let routine = makeRoutine(in: context)
        let teamSession = TeamSession(sets: routine.sets.map(Session.ExerciseSet.init))
        routine.teamSessions.append(teamSession)
        let alice = Athlete(name: "Alice")
        context.insert(alice)
        _ = teamSession.addAthlete(alice, context: context)
        try context.save()

        #expect(routine.sessions.isEmpty)
        #expect(routine.teamSessions.count == 1)
    }
}
