//
//  ActiveSessionSnapshot.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Foundation

/// A phone -> watch (and phone -> Live Activity) snapshot of the currently active session.
///
/// Built entirely from SessionLiveView's live, unpersisted state, since none of this (current
/// super set, exercise, phase, timer) exists in the SwiftData model until a set is saved.
/// Hashable because this doubles as a Live Activity's ActivityAttributes.ContentState, which
/// requires it.
nonisolated struct ActiveSessionSnapshot: Codable, Hashable {
    var sessionStartTime: Date        // identity of the active session
    var routineName: String?
    var superSetName: String
    var phase: Phase
    var exerciseName: String?         // nil in .preSet / .postSet
    var exerciseDetailText: String?   // mirrors SessionLiveView.SetState.exerciseDetails
    var setIndex: Int                 // 0-based; meaningful only when exerciseName != nil
    var setCount: Int
    var repText: String?              // e.g. "Rep 2/5", "Right", "Left", "Side 1/2"
    var timerEndDate: Date?           // nil = no running timer (paused, or n/a)
    var timerDuration: TimeInterval   // total duration, for the watch's progress ring; 0 = no timer

    enum Phase: String, Codable {
        case preSet, ready, active, rest, record, postSet

        /// Shared label mapping so the watch and the Live Activity always agree on phase text.
        var displayName: String {
            switch self {
            case .preSet: return "Up Next"
            case .ready: return "Ready"
            case .active: return "On"
            case .rest: return "Off"
            case .record: return "Rest"
            case .postSet: return "Complete"
            }
        }
    }
}

/// Envelope so "no active session" (nil) round-trips through JSON cleanly.
nonisolated struct ActiveSessionState: Codable {
    var snapshot: ActiveSessionSnapshot?
}
