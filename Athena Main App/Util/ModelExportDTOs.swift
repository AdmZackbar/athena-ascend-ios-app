//
//  ModelExportDTOs.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

/// A single value inside a `DataSet`, re-keyed for JSON export. Mirrors
/// `ExerciseData.Value` case-for-case, but with explicit parameter labels so it encodes
/// as `{"discrete":{"value":8}}` rather than the unlabeled `{"_0":8}` that `Value`'s own
/// underscore-labeled cases would produce.
enum ValueExportDTO: Codable {
    case number(value: Double)
    case discrete(value: Int)
    case range(min: Int, max: Int)
    case text(value: String)
    /// `text` is a rendered rung/move sequence (e.g. "Large Edges: B1-R3-L5"), derived
    /// from `set` via the model's own `CampusSet.Move.text`/`Board.name` — included so
    /// the JSON is legible without decoding `set` first. `set` is the lossless value.
    case campus(text: String, set: SchemaV3.ExerciseData.CampusSet)

    init(_ value: SchemaV3.ExerciseData.Value) {
        switch value {
        case .number(let v): self = .number(value: v)
        case .discrete(let v): self = .discrete(value: v)
        case .range(let min, let max): self = .range(min: min, max: max)
        case .text(let v): self = .text(value: v)
        case .campus(let set):
            let text = "\(set.board.name): \(set.moves.map(\.text).joined(separator: "-"))"
            self = .campus(text: text, set: set)
        }
    }
}

/// Re-keys a `DataSet` (`[ExerciseData.Field: ExerciseData.Value]`) to a
/// `[String: ValueExportDTO]` for export.
///
/// `ExerciseData.Field` has no raw value, so `Dictionary`'s `Encodable` conformance
/// falls back to an unkeyed `[key, value, key, value, ...]` JSON *array* rather than an
/// object whenever `Key` isn't `String`/`Int`/`CodingKeyRepresentable` — and that
/// array's element order follows dictionary iteration order, which is nondeterministic
/// per process. Re-keying to `String` up front avoids both problems.
///
/// `Field` is deliberately NOT retroactively conformed to `CodingKeyRepresentable` to
/// fix this at the source: that conformance is global and would change how every
/// already-persisted `expectedData`/`actualData` blob decodes, silently breaking the
/// production data this app just finished migrating into V3.
func exportDataSet(_ dataSet: SchemaV3.ExerciseData.DataSet) -> [String: ValueExportDTO] {
    Dictionary(uniqueKeysWithValues: dataSet.map { (exportKey(for: $0.key), ValueExportDTO($0.value)) })
}

private func exportKey(for field: SchemaV3.ExerciseData.Field) -> String {
    switch field {
    case .reps: "reps"
    case .repsAlt: "repsAlt"
    case .time: "time"
    case .timeAlt: "timeAlt"
    case .weight: "weight"
    case .weightAlt: "weightAlt"
    case .distance: "distance"
    case .distanceAlt: "distanceAlt"
    case .campus: "campus"
    case .campusAlt: "campusAlt"
    case .notes: "notes"
    }
}

/// Flat, `Codable` mirror of `Athlete` for JSON export via `DataExporter`.
struct AthleteExportDTO: Codable {
    var uuid: UUID
    var name: String
    var firstName: String?
    var lastName: String?
    var birthDate: Date?
    var createdAt: Date

    init(_ athlete: SchemaV3.Athlete) {
        uuid = athlete.uuid
        name = athlete.name
        firstName = athlete.firstName
        lastName = athlete.lastName
        birthDate = athlete.birthDate
        createdAt = athlete.createdAt
    }
}

/// Flat, `Codable` mirror of a library `Exercise` for JSON export. `index` is this
/// exercise's position in `exercises.json` — `RoutineDataExportDTO`/
/// `ExerciseDataExportDTO` reference it by `exerciseIndex` rather than duplicating this
/// DTO inline, so which routine/session slots share the same library exercise (V3's
/// whole reason for having a shared library instead of copies) survives the export
/// instead of being flattened away.
struct ExerciseExportDTO: Codable {
    var name: String
    var category: SchemaV3.Exercise.Category
    var notes: String
    var createdAt: Date

    init(_ exercise: SchemaV3.Exercise) {
        name = exercise.name
        category = exercise.category
        notes = exercise.notes
        createdAt = exercise.createdAt
    }
}

/// Flat, `Codable` mirror of one `RoutineData` row (one exercise slot within a
/// routine's super sets).
struct RoutineDataExportDTO: Codable {
    var position: SchemaV3.ExerciseData.Position
    var exerciseIndex: Int?
    var expectedData: [[String: ValueExportDTO]]

    init(_ routineData: SchemaV3.RoutineData, exerciseIndices: [PersistentIdentifier: Int]) {
        position = routineData.position
        exerciseIndex = routineData.exercise.flatMap { exerciseIndices[$0.persistentModelID] }
        expectedData = routineData.expectedData.map(exportDataSet)
    }
}

/// Flat, `Codable` mirror of `Routine` for JSON export.
struct RoutineExportDTO: Codable {
    var name: String
    var superSets: [SchemaV3.Routine.SuperSet]
    var data: [RoutineDataExportDTO]
    var createdAt: Date

    init(_ routine: SchemaV3.Routine, exerciseIndices: [PersistentIdentifier: Int]) {
        name = routine.name
        superSets = routine.superSets
        data = (routine.data ?? [])
            .sorted { ($0.position.superSetIndex, $0.position.setIndex) < ($1.position.superSetIndex, $1.position.setIndex) }
            .map { RoutineDataExportDTO($0, exerciseIndices: exerciseIndices) }
        createdAt = routine.createdAt
    }
}

/// Flat, `Codable` mirror of one `ExerciseData` row (one exercise slot's recorded data
/// within a session, scoped to one athlete).
struct ExerciseDataExportDTO: Codable {
    var athleteUUID: UUID?
    var position: SchemaV3.ExerciseData.Position
    var exerciseIndex: Int?
    var expectedData: [[String: ValueExportDTO]]
    var actualData: [[String: ValueExportDTO]]
    var notes: String

    init(_ data: SchemaV3.ExerciseData, exerciseIndices: [PersistentIdentifier: Int]) {
        athleteUUID = data.athlete?.uuid
        position = data.position
        exerciseIndex = data.exercise.flatMap { exerciseIndices[$0.persistentModelID] }
        expectedData = data.expectedData.map(exportDataSet)
        actualData = data.actualData.map(exportDataSet)
        notes = data.notes
    }
}

/// Flat, `Codable` mirror of `Session` for JSON export. `routineName` is a snapshot,
/// not a link — matches the app's own fallback-to-name pattern for when a routine has
/// been deleted out from under a session (`Routine.sessions`'s `.nullify` delete rule).
struct SessionExportDTO: Codable {
    var routineName: String?
    var startTime: Date
    var endTime: Date?
    var superSets: [SchemaV3.Routine.SuperSet]
    var notes: String
    var standoutSong: SchemaV3.Session.Song?
    var athleteUUIDs: [UUID]
    var data: [ExerciseDataExportDTO]

    init(_ session: SchemaV3.Session, exerciseIndices: [PersistentIdentifier: Int]) {
        routineName = session.routine?.name
        startTime = session.startTime
        endTime = session.endTime
        superSets = session.superSets
        notes = session.notes
        standoutSong = session.standoutSong
        athleteUUIDs = (session.athletes ?? []).map(\.uuid)
        data = (session.data ?? [])
            .sorted { ($0.position.superSetIndex, $0.position.setIndex) < ($1.position.superSetIndex, $1.position.setIndex) }
            .map { ExerciseDataExportDTO($0, exerciseIndices: exerciseIndices) }
    }
}
