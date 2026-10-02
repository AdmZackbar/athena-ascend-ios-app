//
//  AthenaWatchApp.swift
//  Athena Watch App
//
//  Created by Zach Wassynger on 9/16/26.
//

import HealthKit
import SwiftUI
import WatchKit

/// Forwards the phone's `startWatchApp(with:)` call, and crash recovery, into
/// `WorkoutManager`. Kept separate from `AthenaWatchApp` because `WKApplicationDelegate`
/// requires an `NSObject` conformer, which a `struct App` can't be.
final class AthenaWatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            await WorkoutManager.shared.startWorkout()
        }
    }

    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            await WorkoutManager.shared.recoverWorkout()
        }
    }
}

@main
struct AthenaWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: AthenaWatchAppDelegate

    init() {
        // Start the WCSession handshake as early as possible, rather than waiting for
        // ContentView to appear.
        _ = SessionConnectivity.shared
        Task { await WorkoutManager.shared.requestAuthorization() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
