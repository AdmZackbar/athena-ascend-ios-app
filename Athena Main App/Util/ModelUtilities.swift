//
//  ModelUtilities.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

extension Double {
    var lbsFormat: String {
        return "\(self.formatted(.number.precision(.fractionLength(0...2)))) lb"
    }
}

// ******* //
// ROUTINE //
// ******* //

extension Routine.Order {
    var name: String {
        switch self {
        case .bfs: return "Parallel"
        case .dfs: return "Series"
        }
    }
}

extension Routine.GenericSets.DataType {
    var name: String {
        switch self {
        case .rep: return "Reps"
        case .repWeight: return "Rep/Weight"
        case .time: return "Time"
        case .timeWeight: return "Time/Weight"
        }
    }
    
    var hasTime: Bool {
        switch self {
        case .time, .timeWeight: return true
        case .rep, .repWeight: return false
        }
    }
    
    var hasWeight: Bool {
        switch self {
        case .repWeight, .timeWeight: return true
        case .rep, .time: return false
        }
    }
}

extension Routine.SideType {
    var name: String {
        switch self {
        case .dependent: return "Dependent"
        case .independent: return "Independent"
        }
    }
}


// ******* //
// SESSION //
// ******* //

extension Session {
    var finished: Bool {
        endTime != nil
    }
    
    func getExercises(exercise: Routine.Exercise) -> [Session.Exercise] {
        switch exercise {
        case .generic(let expectedData):
            return sets.flatMap({ $0.exercises }).filter({ $0.isBasedOn(expectedData) })
        case .repeater(let expectedData):
            return sets.flatMap({ $0.exercises }).filter({ $0.isBasedOn(expectedData) })
        case .maxHang(let expectedData):
            return sets.flatMap({ $0.exercises }).filter({ $0.isBasedOn(expectedData) })
        case .campus(let expectedData):
            return sets.flatMap({ $0.exercises }).filter({ $0.isBasedOn(expectedData) })
        }
    }
}


// ********* //
// EXERCISES //
// ********* //

extension Routine.Exercise {
    var name: String {
        switch self {
        case .generic(let d):
            return d.name
        case .repeater(let d):
            return d.text
        case .maxHang(let d):
            return d.tag
        case .campus(let d):
            return d.type.text
        }
    }
    
    var numSets: Int {
        switch self {
        case .generic(let d):
            return d.sets.count
        case .repeater(let d):
            return d.sets.count
        case .maxHang(let d):
            return d.sets.count
        case .campus(let d):
            return d.sets.count
        }
    }
    
    func getDescription(setIndex: Int) -> String {
        switch self {
        case .generic(let d):
            return "\(d.name) (\(setIndex + 1)/\(numSets)): \(d.sets[setIndex].text) \(d.setDetailText)"
        case .repeater(let d):
            return "\(d.tag) (\(setIndex + 1)/\(numSets)): \(d.timeOn)s/\(d.timeOff)s \(d.sets[setIndex].text)"
        case .maxHang(let d):
            return "\(d.tag) (\(setIndex + 1)/\(numSets)): \(d.sets[setIndex].text)"
        case .campus(let d):
            return "\(d.type.text) (\(setIndex + 1)/\(numSets)): \(d.sets[setIndex].text)"
        }
    }
}

extension Session.Exercise {
    var hasData: Bool {
        switch self {
        case .generic(let d):
            return !d.actual.isEmpty
        case .repeater(let d):
            return !d.actual.isEmpty
        case .maxHang(let d):
            return !d.actual.isEmpty
        case .campus(let d):
            return !d.actual.isEmpty
        }
    }
    
    var name: String {
        switch self {
        case .generic(let d):
            return d.expected.name
        case .repeater(let d):
            return d.expected.text
        case .maxHang(let d):
            return d.expected.tag
        case .campus(let d):
            return d.expected.type.text
        }
    }
    
    func getText(setIndex: Int) -> String {
        guard setIndex >= 0 && setIndex < numSets else { return name }
        switch self {
        case .generic(let d):
            return "\(d.expected.sets[setIndex].text) \(d.expected.setDetailText)"
        case .repeater(let d):
            return d.expected.sets[setIndex].text
        case .maxHang(let d):
            return d.expected.sets[setIndex].text
        case .campus(let d):
            return d.expected.sets[setIndex].text
        }
    }
    
    var numSets: Int {
        switch self {
        case .generic(let d):
            return d.expected.sets.count
        case .repeater(let d):
            return d.expected.sets.count
        case .maxHang(let d):
            return d.expected.sets.count
        case .campus(let d):
            return d.expected.sets.count
        }
    }
    
    var numCompletedSets: Int {
        switch self {
        case .generic(let d):
            return d.actual.count
        case .repeater(let d):
            return d.actual.count
        case .maxHang(let d):
            return d.actual.count
        case .campus(let d):
            return d.actual.count
        }
    }
    
    func getDescription(setIndex: Int) -> String {
        switch self {
        case .generic(let d):
            return "\(d.expected.sets[setIndex].text) \(d.expected.setDetailText)"
        case .repeater(let d):
            return "\(d.expected.timeOn)s/\(d.expected.timeOff)s \(d.expected.sets[setIndex].text)"
        case .maxHang(let d):
            return "\(d.expected.sets[setIndex].text)"
        case .campus(let d):
            return "\(d.expected.sets[setIndex].text)"
        }
    }
    
    func isBasedOn(_ basis: Routine.Exercise) -> Bool {
        switch basis {
        case .generic(let data):
            return isBasedOn(data)
        case .repeater(let data):
            return isBasedOn(data)
        case .maxHang(let data):
            return isBasedOn(data)
        case .campus(let data):
            return isBasedOn(data)
        }
    }
    
    func isBasedOn(_ basis: Routine.GenericSets) -> Bool {
        switch self {
        case .generic(let sessionData):
            // Only compare based on name
            return basis.name == sessionData.expected.name
        default:
            return false
        }
    }
    
    func isBasedOn(_ basis: Routine.RepeaterSets) -> Bool {
        switch self {
        case .repeater(let sessionData):
            // Check tag and time on/off
            return basis.tag == sessionData.expected.tag &&
                   basis.timeOn == sessionData.expected.timeOn &&
                   basis.timeOff == sessionData.expected.timeOff
        default:
            return false
        }
    }
    
    func isBasedOn(_ basis: Routine.MaxHangSets) -> Bool {
        switch self {
        case .maxHang(let sessionData):
            // Only compare based on tag
            return basis.tag == sessionData.expected.tag
        default:
            return false
        }
    }
    
    func isBasedOn(_ basis: Routine.CampusSets) -> Bool {
        switch self {
        case .campus(let sessionData):
            // Only compare based on type
            return basis.type == sessionData.expected.type
        default:
            return false
        }
    }
}

extension Routine.GenericSets {
    var setDetailText: String {
        switch dataType {
        case .rep, .repWeight: return "reps"
        case .time, .timeWeight: return "s"
        }
    }
}

extension Routine.GenericSet {
    var text: String {
        return min == max ? min.formatted() : "\(min)-\(max)"
    }
    
    var avg: Int {
        return min + ((max - min) / 2)
    }
}

extension Session.GenericDataSet {
    var repsLeft: Int {
        numReps ?? 0
    }
    
    var repsRight: Int {
        numRepsAlt ?? numReps ?? 0
    }
    
    var timeLeft: Int {
        time ?? 0
    }
    
    var timeRight: Int {
        timeAlt ?? time ?? 0
    }
    
    var weightLeft: Double {
        weight ?? 0
    }
    
    var weightRight: Double {
        weightAlt ?? weight ?? 0
    }
    
    var hasDiffSideData: Bool {
        repsLeft != repsRight || timeLeft != timeRight || weightLeft != weightRight
    }
    
    func toString(_ data: Routine.GenericSets) -> String {
        switch data.dataType {
        case .rep:
            return repToString(data.sideType)
        case .repWeight:
            return repWeightToString(data.sideType)
        case .time:
            return timeToString(data.sideType)
        case .timeWeight:
            return timeWeightToString(data.sideType)
        }
    }
    
    private func repToString(_ sideType: Routine.SideType?) -> String {
        switch sideType {
        case .none:
            return "\(repsLeft) reps"
        case .dependent:
            return "\(repsLeft)/\(repsLeft) reps"
        case .independent:
            return "\(repsLeft)/\(repsRight) reps"
        }
    }
    
    private func repWeightToString(_ sideType: Routine.SideType?) -> String {
        switch sideType {
        case .none:
            return "\(repsLeft) reps @ \(weightLeft.lbsFormat)"
        case .dependent:
            let weightStr = weightLeft.formatted(.number.rounded())
            return "\(repsLeft) reps @ \(weightStr)/\(weightStr) lbs"
        case .independent:
            if repsLeft == repsRight && weightLeft == weightRight {
                let weightStr = weightLeft.formatted(.number.rounded())
                return "\(repsLeft) reps @ \(weightStr)/\(weightStr) lbs"
            } else if repsLeft == repsRight {
                let leftStr = weightLeft.formatted(.number.rounded())
                let rightStr = weightRight.formatted(.number.rounded())
                return "\(repsLeft) reps @ \(leftStr)/\(rightStr) lbs"
            } else if weightLeft == weightRight {
                let weightStr = weightLeft.formatted(.number.rounded())
                return "\(repsLeft)/\(repsRight) reps @ \(weightStr)/\(weightStr) lbs"
            } else {
                let leftStr = weightLeft.formatted(.number.rounded())
                let rightStr = weightRight.formatted(.number.rounded())
                return "\(repsLeft)/\(repsRight) reps @ \(leftStr)/\(rightStr) lbs"
            }
        }
    }
    
    private func timeToString(_ sideType: Routine.SideType?) -> String {
        switch sideType {
        case .none:
            return "\(timeLeft)s"
        case .dependent:
            return "\(timeLeft)s/\(timeLeft)s"
        case .independent:
            return "\(timeLeft)s/\(timeRight)s"
        }
    }
    
    private func timeWeightToString(_ sideType: Routine.SideType?) -> String {
        switch sideType {
        case .none:
            return "\(timeLeft)s @ \(weightLeft.lbsFormat)"
        case .dependent:
            let weightStr = weightLeft.formatted(.number.rounded())
            return "\(timeLeft)s @ \(weightStr)/\(weightStr) lbs"
        case .independent:
            return "\(timeLeft)s @ \(weightLeft.lbsFormat), \(timeRight)s @ \(weightRight.lbsFormat)"
        }
    }
}

extension Routine.RepeaterSets {
    var text: String {
        "\(tag) \(timeOn)s/\(timeOff)s"
    }
}

extension Routine.RepeaterSet {
    var text: String {
        return "\(numReps) reps @ \(weight.lbsFormat)"
    }
}

extension Session.RepeaterSet {
    var text: String {
        return "\(numReps) reps @ \(weight.lbsFormat)"
    }
}

extension Routine.MaxHangSet {
    var targetLeft: Int {
        target
    }
    
    var targetRight: Int {
        targetAlt ?? target
    }
    
    var weightLeft: Double {
        weight
    }
    
    var weightRight: Double {
        weightAlt ?? weight
    }
    
    var text: String {
        if targetLeft == targetRight && weightLeft == weightRight {
            return "L/R \(targetLeft)s @ \(weightLeft.lbsFormat)"
        } else {
            return "L \(targetLeft)s @ \(weightLeft.lbsFormat), R \(targetRight)s @ \(weightRight.lbsFormat)"
        }
    }
    
    var textLeft: String {
        return "\(targetLeft)s @ \(weightLeft.lbsFormat)"
    }
    
    var textRight: String {
        return "\(targetRight)s @ \(weightRight.lbsFormat)"
    }
}

extension Session.MaxHangSet {
    var text: String {
        if timeLeft == timeRight && weightLeft == weightRight {
            return "L/R \(timeLeft)s @ \(weightLeft.lbsFormat)"
        } else {
            return "L \(timeLeft)s @ \(weightLeft.lbsFormat), R \(timeRight)s @ \(weightRight.lbsFormat)"
        }
    }
    
    var timeLeft: Int {
        time ?? 0
    }
    
    var timeRight: Int {
        timeAlt ?? time ?? 0
    }
    
    var weightLeft: Double {
        weight ?? 0
    }
    
    var weightRight: Double {
        weightAlt ?? weight ?? 0
    }
    
    var hasDiffSideData: Bool {
        timeLeft != timeRight || weightLeft != weightRight
    }
}

extension CampusBoard {
    static let largeEdges = CampusBoard(name: "Large Edges")
    static let mediumEdges = CampusBoard(name: "Medium Edges")
    static let smallEdges = CampusBoard(name: "Small Edges")
    static let sloperRungs = CampusBoard(name: "Sloper Rungs", endRung: .full(8), hasHalf: false)
    
    static let allCases = [largeEdges, mediumEdges, smallEdges, sloperRungs]
}

extension [CampusMove] {
    var text: String {
        return "\(self.map({ $0.text }).joined(separator: "-"))"
    }
    
    var flipped: [CampusMove] {
        return self.map({ .init(rung: $0.rung, side: $0.side.flipped) })
    }
}

extension Routine.CampusSets.PlannedSet.Moves {
    var text: String {
        switch self {
        case .defined(let moves):
            return moves.text
        case .baseline(let offsets):
            return "Baseline: \(offsets.map({ $0 >= 0 ? "+\($0)" : "\($0)" }).joined(separator: ", "))"
        case .progressive:
            return "Progressive"
        }
    }
    
    var moves: [CampusMove]? {
        switch self {
        case .defined(let m):
            return m
        default:
            return nil
        }
    }
}

extension Routine.CampusSets.PlannedSet {
    var movesText: String {
        return doMirror ? "\(moves.text) x2" : moves.text
    }
    
    var text: String {
        return board.name.isEmpty ? movesText : "\(board.name): \(movesText)"
    }
}

extension Session.CampusSetPair {
    var hasDiffSideData: Bool {
        alt != nil
    }

    var text: String {
        if let alt {
            return "\(main.moves.text), \(alt.moves.text)"
        }
        return main.moves.text
    }
}
