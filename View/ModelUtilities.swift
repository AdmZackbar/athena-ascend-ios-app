//
//  ModelUtilities.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

extension Routine.Order {
    var name: String {
        switch self {
        case .bfs: return "Parallel"
        case .dfs: return "Series"
        }
    }
}

extension Routine.Side {
    var abbreviation: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        case .both: return "B"
        }
    }
    
    var name: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .both: return "Both"
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
}

extension Routine.Exercise {
    // TODO
    var description: String {
        switch self {
        case .generic(let d):
            return "\(d.name): \(numSets) sets"
        case .repeater(let d):
            return "Repeater: \(d.tag) \(d.timeOn)s/\(d.timeOff)s \(numSets) sets"
        case .maxHang(let d):
            return "Max Hang: \(d.tag) \(numSets) sets"
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
        }
    }
}

extension Session {
    var finished: Bool {
        endTime != nil
    }
}

extension Session.Exercise {
    // TODO
    var description: String {
        switch self {
        case .generic(let d):
            return "\(d.expected.name): \(numSets) sets"
        case .repeater(let d):
            return "Repeater: \(d.expected.tag) \(d.expected.timeOn)s/\(d.expected.timeOff)s \(numSets) sets"
        case .maxHang(let d):
            return "Max Hang: \(d.expected.tag) \(numSets) sets"
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
        }
    }
    
    func getDescription(setIndex: Int) -> String {
        switch self {
        case .generic(let d):
            return "\(d.expected.name) (\(setIndex + 1)/\(numSets)): \(d.expected.sets[setIndex].text) \(d.expected.setDetailText)"
        case .repeater(let d):
            return "\(d.expected.tag) (\(setIndex + 1)/\(numSets)): \(d.expected.timeOn)s/\(d.expected.timeOff)s \(d.expected.sets[setIndex].text)"
        case .maxHang(let d):
            return "\(d.expected.tag) (\(setIndex + 1)/\(numSets)): \(d.expected.sets[setIndex].text)"
        }
    }
}

extension Double {
    var lbsFormat: String {
        return "\(self.formatted(.number.precision(.fractionLength(0...2)))) lb"
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

extension Session.Exercise {
    var hasData: Bool {
        switch self {
        case .generic(let d):
            return !d.actual.isEmpty
        case .repeater(let d):
            return !d.actual.isEmpty
        case .maxHang(let d):
            return !d.actual.isEmpty
        }
    }
}

extension Session.GenericDataSet {
    func weightText(_ multiWeight: Bool) -> String {
        let num = (weight ?? 0).formatted(.number.precision(.fractionLength(0...2)))
        return multiWeight ? "\(num)/\(num) lbs" : "\(num) lbs"
    }
    
    func toString(_ data: Routine.GenericSets) -> String {
        switch data.dataType {
        case .rep:
            return "\(numReps ?? 0) reps"
        case .repWeight:
            return "\(numReps ?? 0) reps @ \(weightText(data.multiWeight ?? false))"
        case .time:
            return "\(time ?? 0)s"
        case .timeWeight:
            return "\(time ?? 0)s @ \(weightText(data.multiWeight ?? false))"
        }
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
    var text: String {
        return "\(side.abbreviation) \(target)s @ \(weight.lbsFormat)"
    }
}

extension Session.MaxHangSet {
    var text: String {
        return "\(side.abbreviation) \(target)s @ \(weight.lbsFormat)"
    }
}
