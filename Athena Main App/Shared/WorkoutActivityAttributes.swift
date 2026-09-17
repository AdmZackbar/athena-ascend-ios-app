//
//  WorkoutActivityAttributes.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/17/26.
//

import ActivityKit
import Foundation

/// Static identity of the mirrored session; the dynamic half is the same snapshot the watch
/// renders, so the Live Activity and the watch can't drift from each other.
nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    typealias ContentState = ActiveSessionSnapshot

    var sessionStartTime: Date
    var routineName: String?
}
