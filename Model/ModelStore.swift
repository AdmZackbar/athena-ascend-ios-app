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

    /// The store filename, matching SwiftData's default location.
    private static let storeName = "default.store"

    /// The SQLite sidecar files that must travel with the store.
    private static let sidecarSuffixes = ["-wal", "-shm"]

    /// Guards against re-copying the legacy store after a successful migration.
    private static let migrationCompleteKey = "AppGroupStoreMigrationComplete"

    private static var groupContainerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            fatalError("App group '\(appGroupIdentifier)' is not available. Check the entitlement and provisioning profile.")
        }
        return url
    }

    /// The directory inside the app group container that holds the store.
    static var directory: URL {
        groupContainerURL.appending(path: "Library/Application Support")
    }

    /// The location of the shared store file.
    static var url: URL {
        directory.appending(path: storeName)
    }

    /// The store's pre-app-group location, used only as a migration source.
    private static var legacyURL: URL {
        URL.applicationSupportDirectory.appending(path: storeName)
    }

    /// Builds the container, migrating any pre-app-group store first.
    static func makeContainer() throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        migrateLegacyStoreIfNeeded()

        let schema = Schema(CurrentSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Copies a pre-app-group store into the group container, once.
    ///
    /// Copies rather than moves so the legacy files remain in place as an
    /// untouched rollback if anything goes wrong.
    private static func migrateLegacyStoreIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationCompleteKey) else { return }

        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path) else { return }
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }

        do {
            try fileManager.copyItem(at: legacyURL, to: url)
            for suffix in sidecarSuffixes {
                let sidecarSource = URL(fileURLWithPath: legacyURL.path + suffix)
                guard fileManager.fileExists(atPath: sidecarSource.path) else { continue }
                let sidecarDestination = URL(fileURLWithPath: url.path + suffix)
                try fileManager.copyItem(at: sidecarSource, to: sidecarDestination)
            }
            defaults.set(true, forKey: migrationCompleteKey)
        } catch {
            print("Failed to migrate legacy SwiftData store into app group container: \(error)")
        }
    }
}
