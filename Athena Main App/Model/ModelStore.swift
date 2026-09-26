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

    /// The active (V3) store's filename.
    ///
    /// A pre-V3 `default.store` file may still sit beside this one in the app-group
    /// directory, left over from the one-time V2→V3 migration — nothing opens it
    /// anymore, but it's an inert rollback copy of the pre-V3 data and is intentionally
    /// not deleted here.
    private static let storeName = "default-v3.store"

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

    /// The location of the active store file.
    static var url: URL {
        directory.appending(path: storeName)
    }

    /// Builds the active container.
    static func makeContainer() throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let schema = Schema(CurrentSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
