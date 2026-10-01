//
//  DataExporterTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/26/26.
//

import Foundation
import SwiftData
import Testing
@testable import Athena

@MainActor
struct DataExporterTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        TestDataModifier.populateContainer(container)
        return container
    }

    private func scratchDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "data-exporter-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func writesExactlyFourFiles() throws {
        let container = try makeContainer()
        let parent = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let directory = try DataExporter.exportAllModels(context: container.mainContext, in: parent)
        let names = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(names == ["athletes.json", "exercises.json", "routines.json", "sessions.json"])
    }

    /// Regression guard: `ExerciseData.DataSet` (`[Field: Value]`) has no usable
    /// `Codable` conformance of its own — `Field` has no raw value, so `Dictionary`'s
    /// `Encodable` conformance falls back to an unkeyed `[key, value, ...]` JSON array
    /// instead of an object. `exportDataSet(_:)` re-keys to `String` specifically to
    /// avoid that; this test asserts the fix actually holds by inspecting the raw JSON
    /// shape rather than trusting the DTOs' own decode.
    @Test func dataSetsEncodeAsStringKeyedObjects() throws {
        let container = try makeContainer()
        let parent = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let directory = try DataExporter.exportAllModels(context: container.mainContext, in: parent)
        let data = try Data(contentsOf: directory.appending(path: "routines.json"))
        let routines = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let allExpectedData = try #require(routines).flatMap { routine -> [[String: Any]] in
            let rows = routine["data"] as? [[String: Any]] ?? []
            return rows.flatMap { $0["expectedData"] as? [[String: Any]] ?? [] }
        }
        let recognizedFields: Set<String> = ["reps", "repsAlt", "time", "timeAlt", "weight", "weightAlt", "distance", "distanceAlt", "campus", "campusAlt", "notes"]
        #expect(allExpectedData.contains { dataSet in dataSet.keys.contains { recognizedFields.contains($0) } })
    }

    /// Regression guard: every V3 relationship (`ExerciseData.athlete`, `.exercise`,
    /// `.session`, `Session.athletes`, `Routine.data`, ...) is implicitly-unwrapped. A
    /// dangling relationship (exactly the scenario someone reaches for "Export Data"
    /// to investigate) must not crash the export.
    @Test func survivesDanglingRelationships() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let orphan = SchemaV3.ExerciseData(
            exercise: SchemaV3.Exercise(category: .generic(name: "Orphan", dataTypes: [.reps], sideType: .none)),
            session: SchemaV3.Session(),
            athlete: SchemaV3.Athlete(name: "Ghost"),
            position: .init(setIndex: 0)
        )
        context.insert(orphan)
        orphan.athlete = nil
        try context.save()

        let parent = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        try DataExporter.exportAllModels(context: context, in: parent)
    }

    @Test func roundTripsAthleteAndExerciseFields() throws {
        let container = try makeContainer()
        let parent = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let directory = try DataExporter.exportAllModels(context: container.mainContext, in: parent)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let athleteData = try Data(contentsOf: directory.appending(path: "athletes.json"))
        let athletes = try decoder.decode([AthleteExportDTO].self, from: athleteData)
        let liveAthletes = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Athlete>())
        #expect(athletes.count == liveAthletes.count)
        #expect(!athletes.isEmpty)
        for athlete in athletes {
            #expect(liveAthletes.contains { $0.uuid == athlete.uuid && $0.name == athlete.name })
        }

        let exerciseData = try Data(contentsOf: directory.appending(path: "exercises.json"))
        let exercises = try decoder.decode([ExerciseExportDTO].self, from: exerciseData)
        let liveExercises = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Exercise>())
        #expect(exercises.count == liveExercises.count)
        #expect(!exercises.isEmpty)
        for exercise in exercises {
            #expect(liveExercises.contains { $0.category == exercise.category })
        }
    }

    @Test func roundTripsSessionUUIDs() throws {
        let container = try makeContainer()
        let parent = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let directory = try DataExporter.exportAllModels(context: container.mainContext, in: parent)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let sessionData = try Data(contentsOf: directory.appending(path: "sessions.json"))
        let sessions = try decoder.decode([SessionExportDTO].self, from: sessionData)
        let liveSessions = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Session>())
        #expect(!sessions.isEmpty)
        #expect(Set(sessions.map(\.uuid)) == Set(liveSessions.map(\.uuid)))
    }
}
