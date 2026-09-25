//
//  ModelStore.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Foundation
import SwiftData

/// Shared configuration for the app group-backed SwiftData store.
///
/// The store lives in the app group container so the iOS app and a companion
/// watchOS app can open the same file.
enum ModelStore {
    /// The app group that hosts the shared store.
    static let appGroupIdentifier = "group.com.wassynger.athena"

    /// The pre-V3 store's filename. Never written to after the V3 cutover — its
    /// continued presence at `legacyV2URL` is what lets a one-time JSON export still
    /// read a user's pre-V3 data via `makeLegacyV2Container()`.
    private static let legacyStoreName = "default.store"

    /// The active (V3) store's filename. Deliberately different from
    /// `legacyStoreName` so provisioning a V3 store can never collide with, or
    /// overwrite, a pre-existing V2 store — the two coexist side by side in the same
    /// app-group directory.
    private static let storeName = "default-v3.store"

    /// The SQLite sidecar files that must travel with a store when it's relocated.
    private static let sidecarSuffixes = ["-wal", "-shm"]

    /// Guards against re-copying the legacy store after a successful migration.
    private static let migrationCompleteKey = "AppGroupStoreMigrationComplete"

    private static var groupContainerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            fatalError("App group '\(appGroupIdentifier)' is not available. Check the entitlement and provisioning profile.")
        }
        return url
    }

    /// The directory inside the app group container that holds both stores.
    static var directory: URL {
        groupContainerURL.appending(path: "Library/Application Support")
    }

    /// The location of the active (V3) store file.
    static var url: URL {
        directory.appending(path: storeName)
    }

    /// The app-group-relocated V2 (or V1, pre-backfill) store. Read-only from here on
    /// — only ever opened via `makeLegacyV2Container()` for a one-time JSON export.
    static var legacyV2URL: URL {
        directory.appending(path: legacyStoreName)
    }

    /// The V2 store's pre-app-group location, used only as a migration source for
    /// `migrateLegacyStoreIfNeeded()`. Unrelated to the V3 cutover — this is about
    /// where the file lives, not which schema version it's in.
    private static var legacySandboxURL: URL {
        URL.applicationSupportDirectory.appending(path: legacyStoreName)
    }

    /// Builds the active V3 container. A freshly provisioned V3 store has nothing on
    /// disk to migrate from, so no `migrationPlan:` is needed here — that only applies
    /// to `makeLegacyV2Container()`'s V1→V2 path.
    static func makeContainer() throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        migrateLegacyStoreIfNeeded()

        let schema = Schema(CurrentSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Opens the legacy V2 store (relocating a pre-app-group store first, and running
    /// the tested V1→V2 backfill if it's still on V1), for a one-time JSON export via
    /// `DataExporter`/`LegacyImport`. Never writes to `url` — entirely separate from
    /// the active V3 container.
    static func makeLegacyV2Container() throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        migrateLegacyStoreIfNeeded()

        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(schema: schema, url: legacyV2URL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: AthenaMigrationPlan.self, configurations: [configuration])
    }

    /// Copies a pre-app-group store into the group container, once.
    ///
    /// Copies rather than moves so the legacy files remain in place as an
    /// untouched rollback if anything goes wrong.
    private static func migrateLegacyStoreIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationCompleteKey) else { return }

        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: legacyV2URL.path) else { return }
        guard fileManager.fileExists(atPath: legacySandboxURL.path) else { return }

        do {
            try fileManager.copyItem(at: legacySandboxURL, to: legacyV2URL)
            for suffix in sidecarSuffixes {
                let sidecarSource = URL(fileURLWithPath: legacySandboxURL.path + suffix)
                guard fileManager.fileExists(atPath: sidecarSource.path) else { continue }
                let sidecarDestination = URL(fileURLWithPath: legacyV2URL.path + suffix)
                try fileManager.copyItem(at: sidecarSource, to: sidecarDestination)
            }
            defaults.set(true, forKey: migrationCompleteKey)
        } catch {
            print("Failed to migrate legacy SwiftData store into app group container: \(error)")
        }
    }
}
