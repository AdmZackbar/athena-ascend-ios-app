//
//  ModelUtilities.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation
import SwiftUI

// Pinned to V2: every extension below operates on V2's nested Codable payload shapes
// (SchemaV2.Routine.Exercise/SchemaV2.Session.Exercise enums, exerciseID UUID-linking). Still load-bearing
// — LegacyImport.swift and ExerciseLibrary.swift call into these.

/// Frozen copy of `CampusExercise.text` (`View/CampusBoardView.swift`), which is what
/// this file has always displayed for a campus payload's label. A local copy rather
/// than a call into that view extension — see `ExerciseLibrary.campusName(for:)` for
/// the same duplication and rationale.
private func campusName(for type: SchemaV2.Routine.CampusSets.Exercise) -> String {
    switch type {
    case .basicLadder: "Basic Ladder"
    case .maxLadder: "Max Ladder"
    case .maxFirst: "Max First"
    case .bumps: "Bumps"
    case .touches: "Touches"
    case .doubles: "Doubles"
    case .downUps: "Down-Ups"
    }
}

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

extension SchemaV2.Athlete {
    var fullName: String? {
        if let firstName, let lastName {
            return "\(firstName) \(lastName)"
        }
        return nil
    }
}

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

extension SchemaV2.Routine.Order {
    var name: String {
        switch self {
        case .bfs: return "Parallel"
        case .dfs: return "Series"
        }
    }
}

extension Routine.SuperSet.Order {
    var name: String {
        switch self {
        case .bfs: return "Parallel"
        case .dfs: return "Series"
        }
    }
}

extension SchemaV2.Routine.GenericSets.DataType {
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

extension SchemaV2.Routine.SideType {
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

extension SchemaV2.Session {
    var finished: Bool {
        endTime != nil
    }

    /// True when this session is one athlete's slice of a `TeamSession` rather than a
    /// standalone session.
    var isTeamEntry: Bool {
        teamSession != nil
    }

    /// Non-nil in practice — the athlete cascade-deletes its sessions, so the fallback
    /// only covers the brief window between `init` and assignment.
    var athleteDisplayName: String {
        athlete?.name ?? "Unknown"
    }

    func getExercises(exercise: SchemaV2.Routine.Exercise) -> [SchemaV2.Session.Exercise] {
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

extension Session {
    var finished: Bool {
        endTime != nil
    }
}


// ********* //
// EXERCISES //
// ********* //

extension SchemaV2.Routine.Exercise {
    var name: String {
        switch self {
        case .generic(let d):
            return d.name
        case .repeater(let d):
            return d.text
        case .maxHang(let d):
            return d.tag
        case .campus(let d):
            return campusName(for: d.type)
        }
    }

    /// Links this payload to its library entry. Nil for pre-V2 data that predates the
    /// backfill, or for a freshly-added exercise that hasn't been saved to the library yet.
    nonisolated var exerciseID: UUID? {
        get {
            switch self {
            case .generic(let d): return d.exerciseID
            case .repeater(let d): return d.exerciseID
            case .maxHang(let d): return d.exerciseID
            case .campus(let d): return d.exerciseID
            }
        }
        set {
            switch self {
            case .generic(var d):
                d.exerciseID = newValue
                self = .generic(d)
            case .repeater(var d):
                d.exerciseID = newValue
                self = .repeater(d)
            case .maxHang(var d):
                d.exerciseID = newValue
                self = .maxHang(d)
            case .campus(var d):
                d.exerciseID = newValue
                self = .campus(d)
            }
        }
    }

    /// The raw, settable identity field backing this exercise's library entry —
    /// `name` for generic, `tag` for repeater/max hang. Campus has no free-text field
    /// (its label is always derived from `type`), so the setter is a no-op there.
    var rawLabel: String {
        get {
            switch self {
            case .generic(let d): return d.name
            case .repeater(let d): return d.tag
            case .maxHang(let d): return d.tag
            case .campus(let d): return campusName(for: d.type)
            }
        }
        set {
            switch self {
            case .generic(var d):
                d.name = newValue
                self = .generic(d)
            case .repeater(var d):
                d.tag = newValue
                self = .repeater(d)
            case .maxHang(var d):
                d.tag = newValue
                self = .maxHang(d)
            case .campus:
                break
            }
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
            return "\(campusName(for: d.type)) (\(setIndex + 1)/\(numSets)): \(d.sets[setIndex].text)"
        }
    }
}

extension SchemaV2.Session.Exercise {
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

    /// Links this snapshot to its library entry, inherited from `expected` (a
    /// `SchemaV2.Routine.*Sets`, which carries the link). Nil for pre-V2 data.
    nonisolated var exerciseID: UUID? {
        get {
            switch self {
            case .generic(let d): return d.expected.exerciseID
            case .repeater(let d): return d.expected.exerciseID
            case .maxHang(let d): return d.expected.exerciseID
            case .campus(let d): return d.expected.exerciseID
            }
        }
        set {
            switch self {
            case .generic(var d):
                d.expected.exerciseID = newValue
                self = .generic(d)
            case .repeater(var d):
                d.expected.exerciseID = newValue
                self = .repeater(d)
            case .maxHang(var d):
                d.expected.exerciseID = newValue
                self = .maxHang(d)
            case .campus(var d):
                d.expected.exerciseID = newValue
                self = .campus(d)
            }
        }
    }

    /// See `SchemaV2.Routine.Exercise.rawLabel` — same semantics, applied to this snapshot's
    /// `expected` payload rather than the routine's live prescription.
    var rawLabel: String {
        get {
            switch self {
            case .generic(let d): return d.expected.name
            case .repeater(let d): return d.expected.tag
            case .maxHang(let d): return d.expected.tag
            case .campus(let d): return campusName(for: d.expected.type)
            }
        }
        set {
            switch self {
            case .generic(var d):
                d.expected.name = newValue
                self = .generic(d)
            case .repeater(var d):
                d.expected.tag = newValue
                self = .repeater(d)
            case .maxHang(var d):
                d.expected.tag = newValue
                self = .maxHang(d)
            case .campus:
                break
            }
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
            return campusName(for: d.expected.type)
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
    
    /// Overwrites the prescription (`expected`) with `template`'s, preserving this
    /// entry's own recorded data (`actual`/`notes`). Used by `TeamSession` when the
    /// shared exercise plan changes after athlete entries already exist. Falls back to
    /// replacing the whole payload if the two are different exercise kinds (shouldn't
    /// happen in practice — the caller always passes the same slot's template).
    mutating func updatingPrescription(from template: SchemaV2.Session.Exercise) {
        switch (self, template) {
        case (.generic(var d), .generic(let t)):
            d.expected = t.expected
            self = .generic(d)
        case (.repeater(var d), .repeater(let t)):
            d.expected = t.expected
            self = .repeater(d)
        case (.maxHang(var d), .maxHang(let t)):
            d.expected = t.expected
            self = .maxHang(d)
        case (.campus(var d), .campus(let t)):
            d.expected = t.expected
            self = .campus(d)
        default:
            self = template
        }
    }

    func isBasedOn(_ basis: SchemaV2.Routine.Exercise) -> Bool {
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
    
    func isBasedOn(_ basis: SchemaV2.Routine.GenericSets) -> Bool {
        switch self {
        case .generic(let sessionData):
            // Only compare based on name
            return basis.name == sessionData.expected.name
        default:
            return false
        }
    }
    
    func isBasedOn(_ basis: SchemaV2.Routine.RepeaterSets) -> Bool {
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
    
    func isBasedOn(_ basis: SchemaV2.Routine.MaxHangSets) -> Bool {
        switch self {
        case .maxHang(let sessionData):
            // Only compare based on tag
            return basis.tag == sessionData.expected.tag
        default:
            return false
        }
    }
    
    func isBasedOn(_ basis: SchemaV2.Routine.CampusSets) -> Bool {
        switch self {
        case .campus(let sessionData):
            // Only compare based on type
            return basis.type == sessionData.expected.type
        default:
            return false
        }
    }
}

extension SchemaV2.Routine.GenericSets {
    var setDetailText: String {
        switch dataType {
        case .rep, .repWeight: return "reps"
        case .time, .timeWeight: return "s"
        }
    }
}

extension SchemaV2.Routine.GenericSet {
    var text: String {
        return min == max ? min.formatted() : "\(min)-\(max)"
    }
    
    var avg: Int {
        return min + ((max - min) / 2)
    }
}

extension SchemaV2.Session.GenericDataSet {
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
    
    func toString(_ data: SchemaV2.Routine.GenericSets) -> String {
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
    
    private func repToString(_ sideType: SchemaV2.Routine.SideType?) -> String {
        switch sideType {
        case .none:
            return "\(repsLeft) reps"
        case .dependent:
            return "\(repsLeft)/\(repsLeft) reps"
        case .independent:
            return "\(repsLeft)/\(repsRight) reps"
        }
    }
    
    private func repWeightToString(_ sideType: SchemaV2.Routine.SideType?) -> String {
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
    
    private func timeToString(_ sideType: SchemaV2.Routine.SideType?) -> String {
        switch sideType {
        case .none:
            return "\(timeLeft)s"
        case .dependent:
            return "\(timeLeft)s/\(timeLeft)s"
        case .independent:
            return "\(timeLeft)s/\(timeRight)s"
        }
    }
    
    private func timeWeightToString(_ sideType: SchemaV2.Routine.SideType?) -> String {
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

extension SchemaV2.Routine.RepeaterSets {
    var text: String {
        "\(tag) \(timeOn)s/\(timeOff)s"
    }
}

extension SchemaV2.Routine.RepeaterSet {
    var text: String {
        return "\(numReps) reps @ \(weight.lbsFormat)"
    }
}

extension SchemaV2.Session.RepeaterSet {
    var text: String {
        return "\(numReps) reps @ \(weight.lbsFormat)"
    }
}

extension SchemaV2.Routine.MaxHangSet {
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

extension SchemaV2.Session.MaxHangSet {
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

extension SchemaV2.CampusSet.Board {
    static let largeEdges = SchemaV2.CampusSet.Board(name: "Large Edges")
    static let mediumEdges = SchemaV2.CampusSet.Board(name: "Medium Edges")
    static let smallEdges = SchemaV2.CampusSet.Board(name: "Small Edges")
    static let sloperRungs = SchemaV2.CampusSet.Board(name: "Sloper Rungs", endRung: .full(8), hasHalf: false)

    static let allCases = [largeEdges, mediumEdges, smallEdges, sloperRungs]
}

extension CampusBoard {
    static let largeEdges = CampusBoard(name: "Large Edges")
    static let mediumEdges = CampusBoard(name: "Medium Edges")
    static let smallEdges = CampusBoard(name: "Small Edges")
    static let sloperRungs = CampusBoard(name: "Sloper Rungs", endRung: .full(8), hasHalf: false)

    static let allCases = [largeEdges, mediumEdges, smallEdges, sloperRungs]
}

extension [SchemaV2.CampusSet.Move] {
    var text: String {
        return "\(self.map({ $0.text }).joined(separator: "-"))"
    }

    var flipped: [SchemaV2.CampusSet.Move] {
        return self.map({ .init(rung: $0.rung, side: $0.side.flipped) })
    }
}

extension SchemaV2.Routine.CampusSets.PlannedSet.Moves {
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
    
    var moves: [SchemaV2.CampusSet.Move]? {
        switch self {
        case .defined(let m):
            return m
        default:
            return nil
        }
    }
}

extension SchemaV2.Routine.CampusSets.PlannedSet {
    var movesText: String {
        return doMirror ? "\(moves.text) x2" : moves.text
    }
    
    var text: String {
        return board.name.isEmpty ? movesText : "\(board.name): \(movesText)"
    }
}

extension SchemaV2.Session.CampusSetPair {
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

extension ExerciseData.DataSet {
    func getText(_ dataType: Exercise.DataType, useAlt: Bool = false) -> String? {
        let field: ExerciseData.Field = {
            switch dataType {
            case .reps: return .reps
            case .time: return .time
            case .weight: return .weight
            case .distance: return .distance
            }
        }()
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
                return self[altField] ?? self[field]
            }
            return self[field]
        }()
        switch value {
        case .text(let str): return str
        case .discrete(let v): return "\(v.formatted())\(dataType.getUnit(v))"
        case .number(let v): return "\(v.formatted(.number.precision(.fractionLength(0...2))))\(dataType.getUnit(Int(v)))"
        case .range(let min, let max): return "[\(min)\(dataType.getUnit(min))-\(max)\(dataType.getUnit(max))]"
        case .campus(let set): return "TODO"
        case .none: return nil
        }
    }
}

extension Exercise.DataType {
    func getUnit(_ value: Int) -> String {
        switch self {
        case .reps: value == 1 ? " rep" : " reps"
        case .time: "s"
        case .weight: value == 1 ? " lb" : " lbs"
        case .distance: "in"
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
