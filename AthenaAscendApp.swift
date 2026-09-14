//
//  AthenaAscendApp.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
import SwiftData

@main
struct AthenaAscendApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(CurrentSchema.models)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
