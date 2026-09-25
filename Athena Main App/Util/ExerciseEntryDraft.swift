//
//  ExerciseEntryDraft.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

// Pinned to V2: stores/converts V2's CampusSet and Routine/Session nested payloads
// directly. No non-view callers besides SessionRunner after the V3 cutover. Fully
// qualified throughout rather than pinned via a shadow alias, since this struct's own
// default (internal) visibility can't expose a `private` type in its stored properties.

/// An in-progress, editable draft of a single set's recorded data, shared across all four
/// exercise kinds (generic, repeater, max hang, campus) while it's being entered in the UI.
struct ExerciseEntryDraft: Codable, Hashable, Equatable {
    var numLeft: Int
    var numRight: Int
    var weightLeft: Double
    var weightRight: Double
    var campusSet: SchemaV2.CampusSet
    var movesAlt: [SchemaV2.CampusSet.Move]
    var notes: String

    init(_ data: SchemaV2.Session.GenericDataSet, format: SchemaV2.Routine.GenericSets, includeNotes: Bool) {
        let notes = includeNotes ? data.notes : ""
        switch format.dataType {
        case .rep, .repWeight:
            self.init(numLeft: data.repsLeft, numRight: data.repsRight, weightLeft: data.weightLeft, weightRight: data.weightRight, notes: notes)
        case .time, .timeWeight:
            self.init(numLeft: data.timeLeft, numRight: data.timeRight, weightLeft: data.weightLeft, weightRight: data.weightRight, notes: notes)
        }
    }

    init(_ data: SchemaV2.Session.RepeaterSet) {
        self.init(numLeft: data.numReps, weightLeft: data.weight, notes: data.notes)
    }

    init(_ data: SchemaV2.Session.MaxHangSet) {
        self.init(numLeft: data.time, numRight: data.timeAlt, weightLeft: data.weight, weightRight: data.weightAlt, notes: data.notes)
    }

    init(_ data: SchemaV2.Session.CampusSetPair) {
        self.init(campusSet: data.main, movesAlt: data.alt?.moves, notes: data.main.notes)
    }

    init(numLeft: Int? = nil, numRight: Int? = nil, weightLeft: Double? = nil, weightRight: Double? = nil, campusSet: SchemaV2.CampusSet? = nil, movesAlt: [SchemaV2.CampusSet.Move]? = nil, notes: String = "") {
        self.numLeft = numLeft ?? 0
        self.numRight = numRight ?? numLeft ?? 0
        self.weightLeft = weightLeft ?? 0
        self.weightRight = weightRight ?? weightLeft ?? 0
        self.campusSet = campusSet ?? .init()
        self.movesAlt = movesAlt ?? []
        self.notes = notes
    }

    func toGeneric(_ data: SchemaV2.Routine.GenericSets, useAlt: Bool) -> SchemaV2.Session.GenericDataSet {
        switch data.dataType {
        case .rep:
            if data.sideType == .independent && useAlt && numLeft != numRight {
                return .init(numReps: numLeft, numRepsAlt: numRight, notes: notes)
            }
            return .init(numReps: numLeft, notes: notes)
        case .repWeight:
            if data.sideType == .independent && useAlt {
                var dataSet = SchemaV2.Session.GenericDataSet(notes: notes)
                if numLeft != numRight {
                    dataSet.numReps = numLeft
                    dataSet.numRepsAlt = numRight
                } else {
                    dataSet.numReps = numLeft
                }
                if weightLeft != weightRight {
                    dataSet.weight = weightLeft
                    dataSet.weightAlt = weightRight
                } else {
                    dataSet.weight = weightLeft
                }
                return dataSet
            }
            return .init(numReps: numLeft, weight: weightLeft, notes: notes)
        case .time:
            if data.sideType == .independent && useAlt && numLeft != numRight {
                return .init(time: numLeft, timeAlt: numRight, notes: notes)
            }
            return .init(time: numLeft, notes: notes)
        case .timeWeight:
            if data.sideType == .independent && useAlt {
                var dataSet = SchemaV2.Session.GenericDataSet(notes: notes)
                if numLeft != numRight {
                    dataSet.time = numLeft
                    dataSet.timeAlt = numRight
                } else {
                    dataSet.time = numLeft
                }
                if weightLeft != weightRight {
                    dataSet.weight = weightLeft
                    dataSet.weightAlt = weightRight
                } else {
                    dataSet.weight = weightLeft
                }
                return dataSet
            }
            return .init(time: numLeft, weight: weightLeft, notes: notes)
        }
    }

    func toRepeater() -> SchemaV2.Session.RepeaterSet {
        return .init(numReps: numLeft, weight: weightLeft, notes: notes)
    }

    func toMaxHang(_ data: SchemaV2.Routine.MaxHangSets, useAlt: Bool) -> SchemaV2.Session.MaxHangSet {
        if data.isSingleArm && useAlt {
            return .init(time: numLeft, timeAlt: numRight, weight: weightLeft, weightAlt: weightRight, notes: notes)
        }
        return .init(time: numLeft, weight: weightLeft, notes: notes)
    }

    func toCampus(_ data: SchemaV2.Routine.CampusSets, useAlt: Bool) -> SchemaV2.Session.CampusSetPair {
        if data.type.canMirror && useAlt {
            return .init(main: .init(board: campusSet.board, moves: campusSet.moves, tempo: campusSet.tempo, notes: notes), alt: .init(board: campusSet.board, moves: movesAlt, tempo: campusSet.tempo, notes: notes))
        }
        return .init(main: .init(board: campusSet.board, moves: campusSet.moves, tempo: campusSet.tempo, notes: notes))
    }
}
