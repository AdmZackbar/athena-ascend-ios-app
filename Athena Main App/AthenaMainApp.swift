//
//  AthenaMainApp.swift
//  Athena
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
import SwiftData

@main
struct AthenaMainApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelStore.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Start the WCSession handshake as early as possible, rather than waiting for the
        // first RoutineSessionView to appear.
        _ = SessionConnectivity.shared
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
