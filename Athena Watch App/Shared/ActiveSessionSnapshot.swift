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
    /// Time left at the moment the timer was paused. Resent once, alongside `timerEndDate`
    /// going nil, so paused displays can show an accurate (if frozen) countdown instead of
    /// just a static "Paused" label. nil whenever `timerEndDate` is set or there's no timer.
    var timerRemaining: TimeInterval?
    /// Editable fields for the current set's actual data, so the watch can offer steppers
    /// during the record phase. nil outside `.record` and for campus exercises (no fields
    /// to mirror there yet). Defaulted so existing call sites (previews, older payloads)
    /// keep compiling/decoding without changes.
    var recordFields: [RecordField]? = nil

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

    /// One steppable field for the current set, mirroring a single `ExerciseData.Field`.
    /// Carries everything the watch needs to render and validate a `Stepper` without any
    /// knowledge of the underlying exercise model - the watch target can't see SwiftData.
    struct RecordField: Codable, Hashable, Identifiable {
        var key: Key
        var name: String          // e.g. "Reps", "Time", "Weight", "Distance"
        var sideLabel: String?    // "Left" / "Right" / "Both", mirroring DataSetEditor; nil if unsided
        var value: Double
        var isDiscrete: Bool      // true -> whole-number steps (.discrete), false -> .number
        var step: Double
        var range: ClosedRange<Double>
        var unitSingular: String  // e.g. " rep", "s", " lb", "\""
        var unitPlural: String    // e.g. " reps", "s", " lbs", "\""

        var id: Key { key }

        /// Identifies which underlying `ExerciseData.Field` this stepper edits.
        enum Key: String, Codable, Hashable {
            case reps, repsAlt, time, timeAlt, weight, weightAlt, distance, distanceAlt
        }
    }
}

/// Envelope so "no active session" (nil) round-trips through JSON cleanly.
nonisolated struct ActiveSessionState: Codable {
    var snapshot: ActiveSessionSnapshot?
}
