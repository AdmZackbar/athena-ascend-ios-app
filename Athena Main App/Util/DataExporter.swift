//
//  DataExporter.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

/// Exports every persisted model to one JSON file each, written into a
/// timestamped sub-directory of `parent`.
enum DataExporter {
    /// Writes `athletes.json`, `exercises.json`, `routines.json`, and `sessions.json`
    /// into a new `Export yyyy-MM-dd HH-mm-ss` directory inside `parent`, returning
    /// that directory's URL. `parent` defaults to the app's real Documents folder but
    /// is overridable so tests can export into a scratch directory instead.
    @discardableResult
    @MainActor
    static func exportAllModels(context: ModelContext, date: Date = .now, in parent: URL = .documentsDirectory) throws -> URL {
        let directory = try makeExportDirectory(date: date, in: parent)

        let exercises = try context.fetch(FetchDescriptor<SchemaV3.Exercise>(sortBy: [SortDescriptor(\.createdAt)]))
        let exerciseIndices = Dictionary(uniqueKeysWithValues: exercises.enumerated().map { ($1.persistentModelID, $0) })

        try write(context.fetch(FetchDescriptor<SchemaV3.Athlete>(sortBy: [SortDescriptor(\.createdAt)])).map(AthleteExportDTO.init),
                   filename: "athletes.json", to: directory)
        try write(exercises.map(ExerciseExportDTO.init),
                   filename: "exercises.json", to: directory)
        try write(context.fetch(FetchDescriptor<SchemaV3.Routine>(sortBy: [SortDescriptor(\.createdAt)]))
                    .map { RoutineExportDTO($0, exerciseIndices: exerciseIndices) },
                   filename: "routines.json", to: directory)
        try write(context.fetch(FetchDescriptor<SchemaV3.Session>(sortBy: [SortDescriptor(\.startTime)]))
                    .map { SessionExportDTO($0, exerciseIndices: exerciseIndices) },
                   filename: "sessions.json", to: directory)

        return directory
    }

    private static func makeExportDirectory(date: Date, in parent: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.timeZone = .current
        let directory = parent.appending(path: "Export \(formatter.string(from: date))")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func write<T: Encodable>(_ value: T, filename: String, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: directory.appending(path: filename), options: .atomic)
    }
}
