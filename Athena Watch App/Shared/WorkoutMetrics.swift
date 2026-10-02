//
//  WorkoutMetrics.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 10/1/26.
//

import Foundation

/// A watch -> phone snapshot of the live HealthKit workout mirrored alongside a session.
/// Hashable so SwiftUI views can diff it the same way `ActiveSessionSnapshot` is diffed.
nonisolated struct WorkoutMetrics: Codable, Hashable {
    var state: State
    var startDate: Date
    /// Duration at the moment this snapshot was taken (`HKWorkoutBuilder.elapsedTime(at:)`).
    /// Not kept ticking locally - the watch resends this periodically, and callers that
    /// want a live countup should derive it from `startDate` while `state == .running`.
    var elapsedTime: TimeInterval
    /// Most recent heart rate sample, in beats per minute. Nil until the first sample arrives.
    var heartRate: Double?
    /// Cumulative active energy burned, in kilocalories.
    var activeEnergy: Double
    /// Cumulative active + basal energy burned, in kilocalories.
    var totalEnergy: Double

    enum State: String, Codable {
        case running, paused, ended
        /// A workout under a minute long when it ended - too short to be meaningful,
        /// so `WorkoutManager` discards it instead of saving it. See
        /// `WorkoutManager.minimumWorkoutDuration`.
        case discarded

        /// True while a HealthKit workout is actually in progress. Both the watch's
        /// `ContentView` and the phone's `SessionLiveView` metrics strip hide themselves
        /// once this goes false, whether the workout ended normally or was discarded.
        var isActive: Bool {
            self == .running || self == .paused
        }
    }
}

/// Messages exchanged over `HKWorkoutSession.sendToRemoteWorkoutSession(data:)`.
/// `.metrics` flows watch -> phone; `.end` and `.linkSession` flow phone -> watch.
nonisolated enum WorkoutRemoteMessage: Codable {
    case metrics(WorkoutMetrics)
    case end
    case linkSession(UUID)
}
