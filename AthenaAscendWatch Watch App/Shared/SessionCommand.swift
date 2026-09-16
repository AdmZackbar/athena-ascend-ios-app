//
//  SessionCommand.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Foundation

/// The reps/time/weight a device's local entry form holds at the moment "Next" is pressed.
///
/// This is the only data that ever travels watch -> phone; nothing about an in-progress entry
/// syncs before that moment. Field names mirror RoutineSessionView.GenericDataSet's core
/// numeric fields, but this type is intentionally decoupled from that private view type.
nonisolated struct ExerciseEntryData: Codable, Equatable {
    var numLeft: Int
    var numRight: Int
    var weightLeft: Double
    var weightRight: Double
}

/// A watch -> phone control command, applied to whichever RoutineSessionView is on screen.
/// Equatable so RoutineSessionView can observe SessionCommandCenter.pendingCommand via onChange.
nonisolated enum SessionCommand: Codable, Equatable {
    case toggleTimer
    case prev
    case next(data: ExerciseEntryData?)
}
