//
//  ActiveSessionSnapshot.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Foundation

/// A phone -> watch (and phone -> Live Activity) snapshot of the currently active exercise
/// session.
///
/// Built entirely from RoutineSessionView's live, unpersisted state, since none of this
/// (current exercise, phase, timer) exists in the SwiftData model until a set is saved.
/// Hashable because this doubles as a Live Activity's ActivityAttributes.ContentState, which
/// requires it.
nonisolated struct ActiveSessionSnapshot: Codable, Hashable {
    var sessionStartTime: Date        // identity of the active session
    var routineName: String?
    var setName: String
    var setIndex: Int                 // 0-based
    var setCount: Int
    var exerciseName: String
    var exerciseDetailText: String    // mirrors Session.Exercise.getDescription(setIndex:)
    var phase: Phase
    var repCurrent: Int
    var repMax: Int
    var timerEndDate: Date?           // nil = no running timer (paused, or n/a)
    var timerDuration: TimeInterval   // total duration, for the watch's progress ring

    // Exercise-level facts, valid regardless of phase.
    var recordsWeight: Bool
    var recordsDualSides: Bool         // full L/R form applies during .rest
    var hasOffPhaseEntry: Bool         // true only for .generic, dataType.hasTime, sideType == .independent
    var unitLabel: String              // "reps" or "s"

    // Meaningful when phase == .rest (all four fields), or when phase == .off and
    // hasOffPhaseEntry is true and timerEndDate == nil (only numRight/weightLeft matter then).
    var suggestedNumLeft: Int
    var suggestedNumRight: Int
    var suggestedWeightLeft: Double
    var suggestedWeightRight: Double

    enum Phase: String, Codable {
        case ready, on, off, rest

        /// Shared label mapping so the watch and the Live Activity always agree on phase text.
        var displayName: String {
            switch self {
            case .ready: return "Ready"
            case .on: return "Active"
            case .off: return "Off"
            case .rest: return "Rest"
            }
        }
    }
}

/// Envelope so "no active session" (nil) round-trips through JSON cleanly.
nonisolated struct ActiveSessionState: Codable {
    var snapshot: ActiveSessionSnapshot?
}
