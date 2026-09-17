//
//  SessionControlIntent.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/17/26.
//

import AppIntents

/// The three Live Activity control buttons, mirroring SessionCommand exactly.
///
/// LiveActivityIntent guarantees the system runs `perform()` in the app's own process (never
/// the widget extension's), so `SessionCommandCenter.shared` here is the same singleton
/// RoutineSessionView already observes for watch-originated commands. This type must still be
/// compiled into the widget extension target too — Button(intent:) needs a concrete type at
/// compile time there — but the widget's own copy of `perform()` never actually executes.
nonisolated struct PreviousExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Previous Exercise"

    func perform() async throws -> some IntentResult {
        await MainActor.run { SessionCommandCenter.shared.submit(.prev) }
        return .result()
    }
}

nonisolated struct ToggleWorkoutTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Workout Timer"

    func perform() async throws -> some IntentResult {
        await MainActor.run { SessionCommandCenter.shared.submit(.toggleTimer) }
        return .result()
    }
}

nonisolated struct NextExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Exercise"

    func perform() async throws -> some IntentResult {
        // nil payload: the Live Activity has no entry form, and handleRemoteCommand already
        // treats that as a plain advance (saving whatever suggested values are showing).
        await MainActor.run { SessionCommandCenter.shared.submit(.next(data: nil)) }
        return .result()
    }
}
