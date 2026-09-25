//
//  DataExporter.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

// Pinned to V2: this is the one-time export path read by the JSON importer, and must
// keep reading the V2 store regardless of what CurrentSchema points at. Fully
// qualified throughout rather than pinned via shadow aliases.

/// Exports every persisted model to one JSON file each, written into a
/// timestamped sub-directory of the app's Documents folder.
enum DataExporter {
    /// Writes `athletes.json`, `exercises.json`, `routines.json`, `sessions.json`,
    /// and `teamSessions.json` into a new `Export yyyy-MM-dd HH-mm-ss` directory
    /// inside Documents, returning that directory's URL.
    @discardableResult
    static func exportAllModels(context: ModelContext, date: Date = .now) throws -> URL {
        let directory = try makeExportDirectory(date: date)

        try write(context.fetch(FetchDescriptor<SchemaV2.Athlete>()).map { AthleteExportDTO($0) },
                   filename: "athletes.json", to: directory)
        try write(context.fetch(FetchDescriptor<SchemaV2.Exercise>()).map { ExerciseExportDTO($0) },
                   filename: "exercises.json", to: directory)
        try write(context.fetch(FetchDescriptor<SchemaV2.Routine>()).map { RoutineExportDTO($0) },
                   filename: "routines.json", to: directory)
        try write(context.fetch(FetchDescriptor<SchemaV2.Session>()).map { SessionExportDTO($0) },
                   filename: "sessions.json", to: directory)
        try write(context.fetch(FetchDescriptor<SchemaV2.TeamSession>()).map { TeamSessionExportDTO($0) },
                   filename: "teamSessions.json", to: directory)

        return directory
    }

    private static func makeExportDirectory(date: Date) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.timeZone = .current
        let directory = URL.documentsDirectory.appending(path: "Export \(formatter.string(from: date))")
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
