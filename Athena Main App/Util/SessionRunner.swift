//
//  SessionRunner.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

extension [ExerciseData] {
    func get(indices: ExerciseIndices) -> ExerciseData? {
        self.filter { $0.position.superSetIndex == indices.superSetIndex && $0.position.setIndex == indices.setIndex }.first
    }
    
    func getNumExercises(superSetIndex: Int) -> Int {
        self.filter { $0.position.superSetIndex == superSetIndex }.count
    }
}

extension ExerciseData {
    var maxNumData: Int {
        max(expectedData.count, actualData.count)
    }
}

extension ExerciseData.Value? {
    var max: Int? {
        switch self {
        case .discrete(let v): return v
        case .number(let v): return Int(v)
        case .range(_, let max): return max
        default: return nil
        }
    }
}

/// Pure logic for stepping through a session's sets: which exercise/set comes next or previous,
/// which phase (ready/on/off/rest) an exercise moves to, how long each phase's timer runs, and
/// how the repeater-rep counter advances. 
struct SessionRunner {
    let superSets: [Routine.SuperSet]
    let data: [ExerciseData]

    // MARK: - Traversal

    func nextIndices(from indices: ExerciseIndices?) -> ExerciseIndices? {
        guard let indices else {
            // Start at beginning
            return .init()
        }
        // Moving to new exercise set, exercise, or routine set
        // Next exercise is determined by set order
        let superSet = superSets[indices.superSetIndex]
        switch superSet.order {
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
        let superSet = superSets[indices.superSetIndex]
        switch superSet.order {
        case .bfs:
            return getPrevBfs(indices)
        case .dfs:
            return getPrevDfs(indices)
        }
    }

    private func getPrevBfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let superSet = superSets[indices.superSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check behind
        for i in (0..<indices.setIndex).reversed() {
            if targetIndex < data.get(indices: .init(indices.superSetIndex, i))?.maxNumData ?? 0 {
                return .init(indices.superSetIndex, i, targetIndex)
            }
        }
        targetIndex -= 1
        if targetIndex < 0 {
            // Exit early if impossible
            return nil
        }
        // Then loop back around to 0 for the next set
        let numExercises = data.getNumExercises(superSetIndex: indices.superSetIndex)
        for i in (0..<numExercises).reversed() {
            if targetIndex < data.get(indices: .init(indices.superSetIndex, i))?.maxNumData ?? 0 {
                return .init(indices.superSetIndex, i, targetIndex)
            }
        }
        // Start screen
        return nil
    }

    private func getNextBfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let superSet = superSets[indices.superSetIndex]
        let numExercises = data.getNumExercises(superSetIndex: indices.superSetIndex)
        var targetIndex = indices.exerciseSetIndex
        // First check ahead
        for i in (indices.setIndex + 1)..<numExercises{
            if targetIndex < data.get(indices: .init(indices.superSetIndex, i))?.maxNumData ?? 0 {
                return .init(indices.superSetIndex, i, targetIndex)
            }
        }
        targetIndex += 1
        // Then loop back around from 0 for the next set
        for i in 0..<numExercises {
            if targetIndex < data.get(indices: .init(indices.superSetIndex, i))?.maxNumData ?? 0 {
                return .init(indices.superSetIndex, i, targetIndex)
            }
        }
        // No other exercises go this high
        if indices.superSetIndex < numExercises - 1 {
            // Move to next routine set
            return .init(indices.superSetIndex + 1)
        }
        // Finish screen
        return nil
    }

    private func getPrevDfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        if indices.exerciseSetIndex > 0 {
            // Prev set within the exercise
            return .init(indices.superSetIndex, indices.setIndex, indices.exerciseSetIndex - 1)
        } else if indices.setIndex > 0 {
            // Next exercise within the routine set
            return .init(indices.superSetIndex, indices.setIndex - 1)
        } else if indices.superSetIndex > 0 {
            // Next set wtihin the routine
            return .init(indices.superSetIndex - 1)
        } else {
            // Finish screen
            return nil
        }
    }

    private func getNextDfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let superSet = superSets[indices.superSetIndex]
        let numExercises = data.getNumExercises(superSetIndex: indices.superSetIndex)
        let numExerciseSets = data.get(indices: indices)?.maxNumData ?? 0
        if indices.exerciseSetIndex < numExerciseSets - 1 {
            // Next set within the exercise
            return .init(indices.superSetIndex, indices.setIndex, indices.exerciseSetIndex + 1)
        } else if indices.setIndex < numExercises - 1 {
            // Next exercise within the routine set
            return .init(indices.superSetIndex, indices.setIndex + 1)
        } else if indices.superSetIndex < superSets.count - 1 {
            // Next set wtihin the routine
            return .init(indices.superSetIndex + 1)
        } else {
            // Finish screen
            return nil
        }
    }

    // MARK: - Phase machine

    func nextPhase(at indices: ExerciseIndices?, phase: ExercisePhase?, rep: RepeaterRep) -> ExercisePhase? {
        guard let indices, let d = data.get(indices: indices) else { return nil }
        switch d.exercise.category {
        case .generic(_, let dataTypes, _):
            switch phase {
            case .ready:
                return dataTypes.contains(.time) ? .on : .rest
            case .on:
                return rep.hasNext ? .off : .rest
            case .off:
                return .on
            case .rest, nil:
                return nil
            }
        case .repeater(_, _, _), .maxHang(_, _):
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
        case .campus(_, _):
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
        guard let indices, let phase, let d = data.get(indices: indices) else { return .zero }
        switch d.exercise.category {
        case .generic(_, let dataTypes, _):
            if dataTypes.contains(.time) {
                switch phase {
                case .ready, .off:
                    return .seconds(5)
                case .on:
                    return .seconds(d.expectedData[indices.exerciseSetIndex][.time].max ?? 0)
                case .rest:
                    return .seconds(superSets[indices.superSetIndex].restTime)
                }
            } else {
                return phase == .rest ? .seconds(superSets[indices.superSetIndex].restTime) : .zero
            }
        case .repeater(_, let timeOn, let timeOff):
            switch phase {
            case .ready:
                return .seconds(10)
            case .on:
                return .seconds(timeOn)
            case .off:
                return .seconds(timeOff)
            case .rest:
                return .seconds(superSets[indices.superSetIndex].restTime)
            }
        case .maxHang(_, _):
            switch phase {
            case .ready:
                return .seconds(10)
            case .on:
                return .seconds(d.expectedData[indices.exerciseSetIndex][.time].max ?? 0)
            case .off:
                return .seconds(20)
            case .rest:
                return .seconds(superSets[indices.superSetIndex].restTime)
            }
        case .campus(_, _):
            switch phase {
            case .ready, .on:
                return .seconds(10)
            case .rest, .off:
                return .seconds(superSets[indices.superSetIndex].restTime)
            }
        }
    }

    // MARK: - Repeater rep

    func repeaterRep(at indices: ExerciseIndices?, phase: ExercisePhase?, current: RepeaterRep) -> RepeaterRep {
        guard let indices, let d = data.get(indices: indices) else { return .zero }
        switch d.exercise.category {
        case .generic(_, let dataTypes, let sideType):
            switch phase {
            case .ready:
                let max: Int = {
                    if dataTypes.contains(.time) {
                        return sideType == .independent ? 2 : 1
                    } else {
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
        case .repeater(_, _, _):
            switch phase {
            case .ready:
                return .init(max: d.expectedData[indices.exerciseSetIndex][.reps].max ?? 0)
            case .on:
                return current.next()
            case .off:
                return current
            default:
                break
            }
        case .maxHang(_, let sideType):
            switch phase {
            case .ready:
                return .init(max: sideType == .independent ? 2 : 1)
            case .on:
                return current.next()
            case .off:
                return current
            default:
                break
            }
        case .campus(_, let mirrorSets):
            switch phase {
            case .ready:
                return .init(max: mirrorSets ? 1 : 0)
            case .off:
                return current.next()
            default:
                break
            }
        }
        return .zero
    }
}
