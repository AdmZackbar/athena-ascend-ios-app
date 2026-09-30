//
//  ModelUtilities.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation
import SwiftUI

// Display-formatting helpers over the V3 models, used throughout the View layer.

extension Double {
    var lbsFormat: String {
        return "\(self.formatted(.number.precision(.fractionLength(0...2)))) lb"
    }
}

extension Binding where Value: Equatable & Sendable {
    /// Returns a boolean binding that is `true` if the wrapped value matches the given case.
    /// Setting it to `false` sets the wrapped value to `nil` or a default state.
    func caseMatches(_ value: Value, orElse defaultValue: Value) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue == value },
            set: { newValue in
                if newValue {
                    self.wrappedValue = value
                } else {
                    self.wrappedValue = defaultValue
                }
            }
        )
    }
}

extension Binding where Value == Bool {
    /// Creates a boolean binding from an optional object binding.
    static func isPresent<T: Sendable>(_ binding: Binding<T?>) -> Binding<Bool> {
        Binding<Bool>(
            get: { binding.wrappedValue != nil },
            set: { newValue in
                if !newValue {
                    binding.wrappedValue = nil
                }
            }
        )
    }
}

// ******* //
// ATHLETE //
// ******* //

extension Athlete {
    var fullName: String? {
        if let firstName, let lastName {
            return "\(firstName) \(lastName)"
        }
        return nil
    }

    var recentDataDate: Date? {
        return self.data.map { $0.session.startTime }.max()
    }
}


// ******* //
// ROUTINE //
// ******* //

extension Routine.SuperSet.Order {
    var name: String {
        switch self {
        case .bfs: return "Parallel"
        case .dfs: return "Series"
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
}


// ********* //
// EXERCISES //
// ********* //

extension ExerciseData.Position: Comparable {
    static func < (lhs: ExerciseData.Position, rhs: ExerciseData.Position) -> Bool {
        if lhs.superSetIndex == rhs.superSetIndex {
            return lhs.setIndex < rhs.setIndex
        }
        return lhs.superSetIndex < rhs.superSetIndex
    }
}

extension ExerciseData.DataSet {
    var hasAlt: Bool {
        self.keys.contains(where: \.isAlt)
    }
    
    func getSummary(useAlt: Bool = false) -> String? {
        var values = Exercise.DataType.allCases.compactMap { useAlt ? getText($0, useAlt: true) ?? getText($0) : getText($0) }
        if let value = useAlt ? self[.campusAlt] ?? self[.campus]?.alt : self[.campus] {
            values.append(value.text)
        }
        return values.joined(separator: ", ")
    }

    func getText(_ dataType: Exercise.DataType, useAlt: Bool = false) -> String? {
        let value: ExerciseData.Value? = self[dataType.getField(alt: useAlt)]
        switch value {
        case .text(let str): return str
        case .discrete(let v): return "\(v.formatted())\(dataType.getUnit(v))"
        case .number(let v): return "\(v.formatted(.number.precision(.fractionLength(0...2))))\(dataType.getUnit(Int(v)))"
        case .range(let min, let max): return "\(min)-\(max)\(dataType.getUnit(max))"
        case .campus(_): return value?.text
        case .none: return nil
        }
    }
    
    /// Performs a intersect-type operation on the two data sets.
    /// If both data sets contain the same value for a given field, that
    /// entry is removed. ONLY the first data set unique values are retained.
    static func ^ (lhs: ExerciseData.DataSet, rhs: ExerciseData.DataSet) -> ExerciseData.DataSet {
        var result: ExerciseData.DataSet = lhs
        rhs.forEach { field, rightVal in
            if let leftVal = lhs[field], leftVal == rightVal {
                result.removeValue(forKey: field)
            }
        }
        return result
    }

    /// Removes all 'alt' field values that match that of the main field values
    func dedupe() -> ExerciseData.DataSet {
        var result = self
        for altField in ExerciseData.Field.altFields {
            if altField == .campusAlt {
                continue
            }
            if let mainField = altField.mainField, self[mainField] == self[altField] {
                result.removeValue(forKey: altField)
            }
        }
        // TODO dedupe flipped version of main for campus
        return result
    }
    
    /// 'Cleans' this data set by removing invalid values for an actual data set
    /// Replaces ranges with their average values, and strips text
    func expectedToActual() -> ExerciseData.DataSet {
        var result = ExerciseData.DataSet()
        self.forEach { field, value in
            switch value {
            case .number(_), .discrete(_), .campus(_):
                // Use value as is
                result[field] = value
            case .range(_, _):
                // Use avg of range
                result[field] = .discrete(value.num!)
            case .text(_):
                // Text unsupported in actual data
                break
            }
        }
        return result
    }
    
    /// Adds the contents of the gibven data set to this one,
    /// and overrides all current values with new ones
    mutating func override(_ rhs: ExerciseData.DataSet) {
        self.merge(rhs, uniquingKeysWith: { $1 })
    }
    
    /// Prepares this data set for persistence as an `actualData` entry, given
    /// whether the exercise can mirror left/right sides and whether the alt
    /// side is currently being tracked.
    func normalized(canMirror: Bool, showAlt: Bool) -> ExerciseData.DataSet {
        if canMirror && !showAlt {
            // Strip out all alt values
            return self.filter { !$0.key.isAlt }
        } else if showAlt {
            // Remove all dupe alt values
            return self.dedupe()
        }
        return self
    }
}

extension [ExerciseData.DataSet] {
    var hasAlt: Bool {
        self.contains(where: { $0.hasAlt })
    }
}

extension Exercise {
    /// Whether this exercise's actual data can differ between left/right sides.
    var canMirror: Bool {
        switch category {
        case .generic(_, _, let sideType): return sideType == .independent
        case .repeater(_, _, _): return false
        case .maxHang(_, let sideType): return sideType == .independent
        case .campus(_, let mirrorSets): return mirrorSets
        }
    }
}

extension Exercise.DataType {
    var field: ExerciseData.Field {
        switch self {
        case .reps: return .reps
        case .time: return .time
        case .weight: return .weight
        case .distance: return .distance
        }
    }

    var altField: ExerciseData.Field {
        switch self {
        case .reps: return .repsAlt
        case .time: return .timeAlt
        case .weight: return .weightAlt
        case .distance: return .distanceAlt
        }
    }

    func getUnit(_ value: Int) -> String {
        switch self {
        case .reps: value == 1 ? " rep" : " reps"
        case .time: "s"
        case .weight: value == 1 ? " lb" : " lbs"
        case .distance: "\""
        }
    }

    func getField(alt: Bool) -> ExerciseData.Field {
        return alt ? altField : field
    }
}

extension ExerciseData.Field {
    static let altFields: [ExerciseData.Field] = [.repsAlt, .timeAlt, .distanceAlt, .weightAlt, .campusAlt]

    var isAlt: Bool {
        Self.altFields.contains(self)
    }

    var mainField: ExerciseData.Field? {
        switch self {
        case .repsAlt: .reps
        case .timeAlt: .time
        case .distanceAlt: .distance
        case .weightAlt: .weight
        case .campusAlt: .campus
        default: nil
        }
    }
}

extension ExerciseData.Value {
    var text: String {
        switch self {
        case .text(let str): str
        case .discrete(let v): v.formatted()
        case .number(let v): v.formatted(.number.precision(.fractionLength(0...2)))
        case .range(let min, let max): "[\(min)-\(max)]"
        case .campus(let set): "(\(set.board.abbreviation)) \(set.moves.text)"
        }
    }
    
    var num: Int? {
        switch self {
        case .discrete(let v): return v
        case .number(let v): return Int(v)
        case .range(let min, let max): return min + ((max - min) / 2)
        default: return nil
        }
    }
    
    var max: Int? {
        if case .range(_, let max) = self {
            return max
        }
        return num
    }
    
    var alt: ExerciseData.Value {
        switch self {
        case .campus(let set): return .campus(set.flipped())
        default: return self
        }
    }
}

extension CampusBoard {
    static let largeEdges = CampusBoard(name: "Large Edges", abbreviation: "L")
    static let mediumEdges = CampusBoard(name: "Medium Edges", abbreviation: "M")
    static let smallEdges = CampusBoard(name: "Small Edges", abbreviation: "S")
    static let sloperRungs = CampusBoard(name: "Sloper Rungs", abbreviation: "SLP", endRung: .full(8), hasHalf: false)

    static let allCases = [largeEdges, mediumEdges, smallEdges, sloperRungs]
}

extension CampusSet {
    func flipped() -> CampusSet {
        var result = self
        result.moves = self.moves.map { .init(rung: $0.rung, side: $0.side.flipped) }
        return result
    }
}

extension [CampusMove] {
    var text: String {
        self.map(\.text).joined(separator: "-")
    }
}
