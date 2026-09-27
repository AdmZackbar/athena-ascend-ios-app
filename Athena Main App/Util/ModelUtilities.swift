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

extension CampusBoard {
    static let largeEdges = CampusBoard(name: "Large Edges")
    static let mediumEdges = CampusBoard(name: "Medium Edges")
    static let smallEdges = CampusBoard(name: "Small Edges")
    static let sloperRungs = CampusBoard(name: "Sloper Rungs", endRung: .full(8), hasHalf: false)

    static let allCases = [largeEdges, mediumEdges, smallEdges, sloperRungs]
}

extension ExerciseData.DataSet {
    var hasAlt: Bool {
        self.keys.contains(where: \.isAlt)
    }
    
    func getSummary(useAlt: Bool = false) -> String? {
        Exercise.DataType.allCases.compactMap { getText($0, useAlt: useAlt) }.joined(separator: ", ")
    }

    func getText(_ dataType: Exercise.DataType, useAlt: Bool = false) -> String? {
        let value: ExerciseData.Value? = {
            if useAlt {
                let altField: ExerciseData.Field = {
                    switch dataType {
                    case .reps: return .repsAlt
                    case .time: return .timeAlt
                    case .weight: return .weightAlt
                    case .distance: return .distanceAlt
                    }
                }()
                return self[altField] ?? self[dataType.field]
            }
            return self[dataType.field]
        }()
        switch value {
        case .text(let str): return str
        case .discrete(let v): return "\(v.formatted())\(dataType.getUnit(v))"
        case .number(let v): return "\(v.formatted(.number.precision(.fractionLength(0...2))))\(dataType.getUnit(Int(v)))"
        case .range(let min, let max): return "\(min)-\(max)\(dataType.getUnit(max))"
        case .campus(let set): return "TODO"
        case .none: return nil
        }
    }
    
    static func ^ (lhs: ExerciseData.DataSet, rhs: ExerciseData.DataSet) -> ExerciseData.DataSet {
        var result: ExerciseData.DataSet = lhs
        rhs.forEach { field, rightVal in
            if let leftVal = lhs[field], leftVal == rightVal {
                result.removeValue(forKey: field)
            }
        }
        return result
    }

    func dedupe() -> ExerciseData.DataSet {
        var result = self
        for altField in ExerciseData.Field.altFields {
            if let mainField = altField.mainField, self[mainField] == self[altField] {
                result.removeValue(forKey: altField)
            }
        }
        return result
    }
}

extension [ExerciseData.DataSet] {
    var hasAlt: Bool {
        self.contains(where: { $0.hasAlt })
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
        case .distance: "in"
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
        case .campus(let set): "TODO"
        }
    }
}
