//
//  ExerciseEntryDraft.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

/// An in-progress, editable draft of a single set's recorded data, shared across all four
/// exercise kinds (generic, repeater, max hang, campus) while it's being entered in the UI.
struct ExerciseEntryDraft: Codable, Hashable, Equatable {
    var numLeft: Int
    var numRight: Int
    var weightLeft: Double
    var weightRight: Double
    var campusSet: CampusSet
    var movesAlt: [CampusMove]
    var notes: String

    init(_ data: Session.GenericDataSet, format: Routine.GenericSets, includeNotes: Bool) {
        let notes = includeNotes ? data.notes : ""
        switch format.dataType {
        case .rep, .repWeight:
            self.init(numLeft: data.repsLeft, numRight: data.repsRight, weightLeft: data.weightLeft, weightRight: data.weightRight, notes: notes)
        case .time, .timeWeight:
            self.init(numLeft: data.timeLeft, numRight: data.timeRight, weightLeft: data.weightLeft, weightRight: data.weightRight, notes: notes)
        }
    }

    init(_ data: Session.RepeaterSet) {
        self.init(numLeft: data.numReps, weightLeft: data.weight, notes: data.notes)
    }

    init(_ data: Session.MaxHangSet) {
        self.init(numLeft: data.time, numRight: data.timeAlt, weightLeft: data.weight, weightRight: data.weightAlt, notes: data.notes)
    }

    init(_ data: Session.CampusSetPair) {
        self.init(campusSet: data.main, movesAlt: data.alt?.moves, notes: data.main.notes)
    }

    init(numLeft: Int? = nil, numRight: Int? = nil, weightLeft: Double? = nil, weightRight: Double? = nil, campusSet: CampusSet? = nil, movesAlt: [CampusMove]? = nil, notes: String = "") {
        self.numLeft = numLeft ?? 0
        self.numRight = numRight ?? numLeft ?? 0
        self.weightLeft = weightLeft ?? 0
        self.weightRight = weightRight ?? weightLeft ?? 0
        self.campusSet = campusSet ?? .init()
        self.movesAlt = movesAlt ?? []
        self.notes = notes
    }

    func toGeneric(_ data: Routine.GenericSets, useAlt: Bool) -> Session.GenericDataSet {
        switch data.dataType {
        case .rep:
            if data.sideType == .independent && useAlt && numLeft != numRight {
                return .init(numReps: numLeft, numRepsAlt: numRight, notes: notes)
            }
            return .init(numReps: numLeft, notes: notes)
        case .repWeight:
            if data.sideType == .independent && useAlt {
                var dataSet = Session.GenericDataSet(notes: notes)
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
                var dataSet = Session.GenericDataSet(notes: notes)
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

    func toRepeater() -> Session.RepeaterSet {
        return .init(numReps: numLeft, weight: weightLeft, notes: notes)
    }

    func toMaxHang(_ data: Routine.MaxHangSets, useAlt: Bool) -> Session.MaxHangSet {
        if data.isSingleArm && useAlt {
            return .init(time: numLeft, timeAlt: numRight, weight: weightLeft, weightAlt: weightRight, notes: notes)
        }
        return .init(time: numLeft, weight: weightLeft, notes: notes)
    }

    func toCampus(_ data: Routine.CampusSets, useAlt: Bool) -> Session.CampusSetPair {
        if data.type.canMirror && useAlt {
            return .init(main: .init(board: campusSet.board, moves: campusSet.moves, tempo: campusSet.tempo, notes: notes), alt: .init(board: campusSet.board, moves: movesAlt, tempo: campusSet.tempo, notes: notes))
        }
        return .init(main: .init(board: campusSet.board, moves: campusSet.moves, tempo: campusSet.tempo, notes: notes))
    }
}
