//
//  SessionRunner.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

/// Pure logic for stepping through a session's sets: which exercise/set comes next or previous,
/// which phase (ready/on/off/rest) an exercise moves to, how long each phase's timer runs, and
/// how the repeater-rep counter advances. Operates on a snapshot of `Session.ExerciseSet` values
/// rather than the `Session` model itself, so it needs no `ModelContext` and is fully testable.
struct SessionRunner {
    let sets: [Session.ExerciseSet]

    // MARK: - Traversal

    func nextIndices(from indices: ExerciseIndices?) -> ExerciseIndices? {
        guard let indices else {
            // Start at beginning
            return .init()
        }
        // Moving to new exercise set, exercise, or routine set
        // Next exercise is determined by set order
        let set = sets[indices.routineSetIndex]
        switch set.order {
        case .bfs:
            return getNextBfs(indices)
        case .dfs:
            return getNextDfs(indices)
        }
    }

    func prevIndices(from indices: ExerciseIndices?) -> ExerciseIndices? {
        guard let indices else {
            // Can't go backward from start
            return nil
        }
        // Moving to new exercise set, exercise, or routine set
        // Next exercise is determined by set order
        let set = sets[indices.routineSetIndex]
        switch set.order {
        case .bfs:
            return getPrevBfs(indices)
        case .dfs:
            return getPrevDfs(indices)
        }
    }

    private func getPrevBfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let set = sets[indices.routineSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check behind
        for i in (0..<indices.setExerciseIndex).reversed() {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        targetIndex -= 1
        if targetIndex < 0 {
            // Exit early if impossible
            return nil
        }
        // Then loop back around to 0 for the next set
        for i in (0..<set.exercises.count).reversed() {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        // Start screen
        return nil
    }

    private func getNextBfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let set = sets[indices.routineSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check ahead
        for i in (indices.setExerciseIndex + 1)..<set.exercises.count {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        targetIndex += 1
        // Then loop back around from 0 for the next set
        for i in 0..<set.exercises.count {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        // No other exercises go this high
        if indices.routineSetIndex < sets.count - 1 {
            // Move to next routine set
            return .init(indices.routineSetIndex + 1)
        }
        // Finish screen
        return nil
    }

    private func getPrevDfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        if indices.exerciseSetIndex > 0 {
            // Prev set within the exercise
            return .init(indices.routineSetIndex, indices.setExerciseIndex, indices.exerciseSetIndex - 1)
        } else if indices.setExerciseIndex > 0 {
            // Next exercise within the routine set
            return .init(indices.routineSetIndex, indices.setExerciseIndex - 1)
        } else if indices.routineSetIndex > 0 {
            // Next set wtihin the routine
            return .init(indices.routineSetIndex - 1)
        } else {
            // Finish screen
            return nil
        }
    }

    private func getNextDfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let set = sets[indices.routineSetIndex]
        let exercise = set.exercises[indices.setExerciseIndex]
        if indices.exerciseSetIndex < exercise.numSets - 1 {
            // Next set within the exercise
            return .init(indices.routineSetIndex, indices.setExerciseIndex, indices.exerciseSetIndex + 1)
        } else if indices.setExerciseIndex < set.exercises.count - 1 {
            // Next exercise within the routine set
            return .init(indices.routineSetIndex, indices.setExerciseIndex + 1)
        } else if indices.routineSetIndex < sets.count - 1 {
            // Next set wtihin the routine
            return .init(indices.routineSetIndex + 1)
        } else {
            // Finish screen
            return nil
        }
    }

    // MARK: - Phase machine

    func nextPhase(at indices: ExerciseIndices?, phase: ExercisePhase?, rep: RepeaterRep) -> ExercisePhase? {
        guard let indices else { return nil }
        let exercise = sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            switch phase {
            case .ready:
                switch d.expected.dataType {
                case .time, .timeWeight:
                    return .on
                case .rep, .repWeight:
                    return .rest
                }
            case .on:
                return rep.hasNext ? .off : .rest
            case .off:
                return .on
            case .rest, nil:
                return nil
            }
        case .repeater(_), .maxHang(_):
            switch phase {
            case .ready:
                return .on
            case .on:
                return rep.hasNext ? .off : .rest
            case .off:
                return .on
            case .rest, nil:
                return nil
            }
        case .campus(_):
            switch phase {
            case .ready:
                return rep.hasNext ? .off : .rest
            case .on, .off:
                return .rest
            case .rest, nil:
                return nil
            }
        }
    }

    func prevPhase(from phase: ExercisePhase?) -> ExercisePhase? {
        switch phase {
        case .ready, nil:
            return nil
        default:
            return .ready
        }
    }

    // MARK: - Timer duration

    func timerDuration(at indices: ExerciseIndices?, phase: ExercisePhase?) -> Duration {
        guard let indices, let phase else { return .zero }
        let set = sets[indices.routineSetIndex]
        let exercise = set.exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            if d.expected.dataType.hasTime {
                switch phase {
                case .ready, .off:
                    return .seconds(5)
                case .on:
                    return .seconds(d.expected.sets[indices.exerciseSetIndex].max)
                case .rest:
                    return .seconds(set.restTime)
                }
            } else {
                return phase == .rest ? .seconds(set.restTime) : .zero
            }
        case .repeater(let d):
            switch phase {
            case .ready:
                return .seconds(10)
            case .on:
                return .seconds(d.expected.timeOn)
            case .off:
                return .seconds(d.expected.timeOff)
            case .rest:
                return .seconds(set.restTime)
            }
        case .maxHang(let d):
            switch phase {
            case .ready:
                return .seconds(10)
            case .on:
                return .seconds(d.expected.sets[indices.exerciseSetIndex].target)
            case .off:
                return .seconds(20)
            case .rest:
                return .seconds(set.restTime)
            }
        case .campus(_):
            switch phase {
            case .ready, .on:
                return .seconds(10)
            case .rest, .off:
                return .seconds(set.restTime)
            }
        }
    }

    // MARK: - Repeater rep

    func repeaterRep(at indices: ExerciseIndices?, phase: ExercisePhase?, current: RepeaterRep) -> RepeaterRep {
        let exercise: Session.Exercise? = indices.map { sets[$0.routineSetIndex].exercises[$0.setExerciseIndex] }
        switch exercise {
        case .generic(let d):
            switch phase {
            case .ready:
                let max: Int = {
                    switch d.expected.dataType {
                    case .time, .timeWeight:
                        return d.expected.sideType == .independent ? 2 : 1
                    case .rep, .repWeight:
                        return 0
                    }
                }()
                return .init(max: max)
            case .on:
                return current.next()
            case .off:
                return current
            default:
                break
            }
        case .repeater(let d):
            switch phase {
            case .ready:
                return .init(max: d.expected.sets[indices!.exerciseSetIndex].numReps)
            case .on:
                return current.next()
            case .off:
                return current
            default:
                break
            }
        case .maxHang(let d):
            switch phase {
            case .ready:
                return .init(max: d.expected.isSingleArm ? 2 : 1)
            case .on:
                return current.next()
            case .off:
                return current
            default:
                break
            }
        case .campus(let d):
            switch phase {
            case .ready:
                return .init(max: d.expected.sets[indices!.exerciseSetIndex].doMirror ? 1 : 0)
            case .off:
                return current.next()
            default:
                break
            }
        case nil:
            break
        }
        return .zero
    }

    // MARK: - Draft data

    /// Builds the editable draft for the given set: prior data for this exact set if it's
    /// already been recorded, seeded expected values otherwise. Generic exercises additionally
    /// prefer the previous session's actual data over expected data, when available.
    func draft(at indices: ExerciseIndices?, previous: PreviousSessionLookup) -> ExerciseEntryDraft {
        guard let indices else { return .init() }
        let exercise = sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            // Try to load from previous session if it exists
            if let prevData = previous.generic(at: indices) {
                return .init(prevData.1, format: prevData.0.expected, includeNotes: false)
            }
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex], format: d.expected, includeNotes: true)
            } else {
                // Load from expected (and prev data if possible)
                var data = ExerciseEntryDraft(numLeft: d.expected.sets[indices.exerciseSetIndex].avg)
                if let latest = d.actual.last {
                    data.weightLeft = latest.weightLeft
                    data.weightRight = latest.weightRight
                }
                return data
            }
        case .repeater(let d):
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex])
            } else {
                // Load from expected
                let expected = d.expected.sets[indices.exerciseSetIndex]
                return .init(numLeft: expected.numReps, weightLeft: expected.weight)
            }
        case .maxHang(let d):
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex])
            } else {
                // Load from expected
                let expected = d.expected.sets[indices.exerciseSetIndex]
                return .init(numLeft: expected.target, weightLeft: expected.weight)
            }
        case .campus(let d):
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex])
            } else {
                // Load from expected
                let expected = d.expected.sets[indices.exerciseSetIndex]
                let doMirror = expected.doMirror && d.expected.type.canMirror
                if case .defined(let moves) = expected.moves {
                    return .init(campusSet: .init(board: expected.board, moves: moves), movesAlt: doMirror ? moves.flipped : nil)
                }
                return .init(campusSet: .init(board: expected.board))
            }
        }
    }

    /// Writes a draft's data back into the given set's exercise, appending a new recorded set
    /// or overwriting the one at `indices.exerciseSetIndex` if it already exists.
    static func apply(_ draft: ExerciseEntryDraft, at indices: ExerciseIndices, allowMultiSide: Bool, to sets: inout [Session.ExerciseSet]) {
        let exercise = sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            var newActual: [Session.GenericDataSet] = d.actual
            let updatedData: Session.GenericDataSet = draft.toGeneric(d.expected, useAlt: d.expected.sideType == .independent && (d.expected.dataType.hasTime || allowMultiSide))
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = updatedData
            } else {
                newActual.append(updatedData)
            }
            sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .generic(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .repeater(let d):
            var newActual: [Session.RepeaterSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = draft.toRepeater()
            } else {
                newActual.append(draft.toRepeater())
            }
            sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .repeater(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .maxHang(let d):
            var newActual: [Session.MaxHangSet] = d.actual
            let updatedData = draft.toMaxHang(d.expected, useAlt: d.expected.isSingleArm && allowMultiSide)
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = updatedData
            } else {
                newActual.append(updatedData)
            }
            sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .maxHang(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .campus(let d):
            var newActual: [Session.CampusSetPair] = d.actual
            let updatedData = draft.toCampus(d.expected, useAlt: d.expected.type.canMirror && allowMultiSide)
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = updatedData
            } else {
                newActual.append(updatedData)
            }
            sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .campus(.init(expected: d.expected, actual: newActual, notes: d.notes))
        }
    }
}

/// Looks up a specific set's recorded data from a previous session, for the "here's what you did
/// last time" hints shown while performing the current session's matching set.
struct PreviousSessionLookup {
    private let sets: [Session.ExerciseSet]?

    init(_ session: Session?) {
        self.sets = session?.sets
    }

    private func exercise(at indices: ExerciseIndices) -> Session.Exercise? {
        guard let sets, indices.routineSetIndex < sets.count else { return nil }
        let set = sets[indices.routineSetIndex]
        guard indices.setExerciseIndex < set.exercises.count else { return nil }
        return set.exercises[indices.setExerciseIndex]
    }

    func generic(at indices: ExerciseIndices) -> (Session.GenericData, Session.GenericDataSet)? {
        guard case .generic(let d) = exercise(at: indices), indices.exerciseSetIndex < d.actual.count else { return nil }
        return (d, d.actual[indices.exerciseSetIndex])
    }

    func repeater(at indices: ExerciseIndices) -> Session.RepeaterSet? {
        guard case .repeater(let d) = exercise(at: indices), indices.exerciseSetIndex < d.actual.count else { return nil }
        return d.actual[indices.exerciseSetIndex]
    }

    func maxHang(at indices: ExerciseIndices) -> Session.MaxHangSet? {
        guard case .maxHang(let d) = exercise(at: indices), indices.exerciseSetIndex < d.actual.count else { return nil }
        return d.actual[indices.exerciseSetIndex]
    }

    func campus(at indices: ExerciseIndices) -> Session.CampusSetPair? {
        guard case .campus(let d) = exercise(at: indices), indices.exerciseSetIndex < d.actual.count else { return nil }
        return d.actual[indices.exerciseSetIndex]
    }
}
