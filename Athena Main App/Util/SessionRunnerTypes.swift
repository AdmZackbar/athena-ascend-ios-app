//
//  SessionRunnerTypes.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

/// Identifies a specific set of a specific exercise within a session's sets.
nonisolated struct ExerciseIndices: Codable, Hashable, Equatable {
    var routineSetIndex: Int
    var setExerciseIndex: Int
    var exerciseSetIndex: Int

    init(_ routineSetIndex: Int = 0, _ setExerciseIndex: Int = 0, _ exerciseSetIndex: Int = 0) {
        self.routineSetIndex = routineSetIndex
        self.setExerciseIndex = setExerciseIndex
        self.exerciseSetIndex = exerciseSetIndex
    }
}

/// The phase an in-progress exercise is currently in. Named to match
/// `ActiveSessionSnapshot.Phase`, which `RoutineSessionView` maps this onto for the watch.
enum ExercisePhase: String, Codable, Hashable, Equatable {
    case ready
    case on
    case off
    case rest
}

/// Tracks progress through a repeated on/off cycle (repeater sets, independent-sided timed
/// generic exercises, single-arm max hangs, mirrored campus moves).
struct RepeaterRep: Codable, Hashable, Equatable {
    static let zero = RepeaterRep(max: 0)

    let current: Int
    let max: Int

    init(current: Int = 0, max: Int) {
        self.current = current
        self.max = max
    }

    var hasNext: Bool {
        current < max
    }

    func next() -> RepeaterRep {
        if hasNext {
            return .init(current: current + 1, max: max)
        }
        return self
    }
}
