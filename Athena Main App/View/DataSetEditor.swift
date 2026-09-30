//
//  DataSetEditor.swift
//  Athena
//
//  Created by Zach Wassynger on 9/29/26.
//

import SwiftUI

extension Exercise.DataType {
    var minValue: Int {
        switch self {
        case .reps, .time: 0
        case .weight, .distance: -1000
        }
    }
    
    var maxValue: Int {
        1000
    }
    
    var stepperIntRange: ClosedRange<Int> {
        minValue...maxValue
    }
    
    var stepperDoubleRange: ClosedRange<Double> {
        Double(minValue)...Double(maxValue)
    }
}

/// Edits a single `ExerciseData.DataSet`, adapting its fields to the given
/// exercise's category (generic/repeater/max hang/campus) and to which
/// side(s) of a mirrored exercise are currently being recorded.
///
/// Used both by `ExerciseDataEditSheet` (editing any set after the fact) and
/// by `SessionLiveView` (editing the current set during the record phase).
struct DataSetEditor: View {
    /// Which side(s) of a (potentially) mirrored exercise this editor should expose.
    enum Sides {
        /// The exercise never mirrors sides - only the main field is used.
        case single
        /// The exercise can mirror, but only one shared value is currently being
        /// entered (labeled "Both"), written to the main field.
        case both
        /// The exercise can mirror and both sides should be shown side-by-side,
        /// writing to the main and alt fields respectively.
        case split
        /// Only the "Left" side (main field) is being recorded this pass.
        case left
        /// Only the "Right" side (alt field) is being recorded this pass.
        case right
    }

    let exercise: Exercise
    @Binding var dataSet: ExerciseData.DataSet
    var sides: Sides
    var discreteStep: Int = 1
    var numberStep: Double = 5

    var body: some View {
        Group {
            switch exercise.category {
            case .generic(_, let dataTypes, _):
                // Force consistent order
                ForEach(Exercise.DataType.allCases.enumerated(), id: \.offset) { offset, dataType in
                    if dataTypes.contains(dataType) {
                        stepperGroup(dataType: dataType)
                    }
                }
            case .repeater(_, _, _):
                stepperGroup(dataType: .reps)
                stepperGroup(dataType: .weight)
            case .maxHang(_, _):
                stepperGroup(dataType: .time)
                stepperGroup(dataType: .weight)
            case .campus(_, _):
                if sides != .right {
                    campusEditor(alt: false)
                }
                if sides == .split || sides == .right {
                    campusEditor(alt: true)
                }
            }
            TextField("Notes", text: .init(get: {
                getString(.notes)
            }, set: { newValue in
                if newValue.isEmpty {
                    dataSet.removeValue(forKey: .notes)
                } else {
                    dataSet[.notes] = .text(newValue)
                }
            })).textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }.onAppear(perform: normalizeData)
    }
    
    func normalizeData() {
        // Pre-populate reverse side data if applicable
        if sides == .split || sides == .right {
            for altField in ExerciseData.Field.altFields {
                if let mainField = altField.mainField {
                    if let mainValue = dataSet[mainField], dataSet[altField] == nil {
                        dataSet[altField] = mainValue.alt
                    } else if let altValue = dataSet[altField], dataSet[mainField] == nil {
                        dataSet[mainField] = altValue.alt
                    }
                }
            }
        }
        // Pre-populate fields with default data as needed
        for field in dataFields {
            let defaultValue: ExerciseData.Value? = {
                switch field {
                case .time, .timeAlt, .reps, .repsAlt, .distance, .distanceAlt:
                    return .discrete(0)
                case .weight, .weightAlt:
                    return .number(0)
                default:
                    return nil
                }
            }()
            if let defaultValue, dataSet[field] == nil {
                dataSet[field] = defaultValue
            }
        }
    }
    
    var dataFields: [ExerciseData.Field] {
        switch exercise.category {
        case .generic(_, let dataTypes, _):
            return dataTypes.flatMap { [$0.field, $0.altField] }
        case .repeater(_, _, _):
            return [.reps, .weight, .repsAlt, .weightAlt]
        case .maxHang(_, _):
            return [.time, .weight, .timeAlt, .weightAlt]
        case .campus(_, _):
            return [.campus, .campusAlt]
        }
    }

    @ViewBuilder
    private func stepperGroup(dataType: Exercise.DataType) -> some View {
        switch sides {
        case .split:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    stepper(dataType: dataType, alt: false)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    stepper(dataType: dataType, alt: true)
                }
            }
        case .both:
            VStack(alignment: .leading, spacing: 2) {
                Text("Both")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                stepper(dataType: dataType, alt: false)
            }
        case .single, .left:
            stepper(dataType: dataType, alt: false)
        case .right:
            stepper(dataType: dataType, alt: true)
        }
    }

    @ViewBuilder
    private func stepper(dataType: Exercise.DataType, alt: Bool) -> some View {
        switch dataType {
        case .reps, .time, .distance:
            let resolved = (alt ? getInt(dataType.altField) : getInt(dataType.field)) ?? 0
            Stepper("\(resolved)\(dataType.getUnit(resolved))", value: .init(get: {
                resolved
            }, set: { newValue in
                dataSet[dataType.getField(alt: alt)] = .discrete(newValue)
            }), in: dataType.stepperIntRange, step: discreteStep)
        case .weight:
            let resolved = (alt ? getDouble(dataType.altField) : getDouble(dataType.field)) ?? 0
            Stepper("\(resolved.formatted(.number.precision(.fractionLength(0...1))))\(dataType.getUnit(Int(resolved)))", value: .init(get: {
                resolved
            }, set: { newValue in
                dataSet[dataType.getField(alt: alt)] = .number(newValue)
            }), in: dataType.stepperDoubleRange, step: numberStep, format: .number.precision(.fractionLength(0...1)))
        }
    }

    @ViewBuilder
    private func campusEditor(alt: Bool) -> some View {
        let current: CampusSet = {
            if alt {
                return getCampusSet(.campusAlt) ?? .init(board: .largeEdges, moves: [])
            }
            return getCampusSet(.campus) ?? .init(board: .largeEdges, moves: [])
        }()
        NavigationLink {
            CampusBoardView(set: current) { newSet in
                dataSet[alt ? .campusAlt : .campus] = .campus(newSet)
            }
        } label: {
            HStack {
                if !current.moves.isEmpty {
                    Text("(\(current.board.abbreviation)) \(current.moves.text)")
                } else {
                    Text("No Moves")
                        .italic()
                }
                Spacer()
            }.contentShape(Rectangle())
        }
    }

    private func getInt(_ field: ExerciseData.Field) -> Int? {
        switch dataSet[field] {
        case .discrete(let v): return v
        default: return nil
        }
    }

    private func getDouble(_ field: ExerciseData.Field) -> Double? {
        switch dataSet[field] {
        case .number(let v): return v
        default: return nil
        }
    }

    private func getString(_ field: ExerciseData.Field) -> String {
        switch dataSet[field] {
        case .text(let str): return str
        default: return ""
        }
    }

    private func getCampusSet(_ field: ExerciseData.Field) -> CampusSet? {
        switch dataSet[field] {
        case .campus(let set): return set
        default: return nil
        }
    }
}

#Preview("Generic") {
    @Previewable @State var dataSet: ExerciseData.DataSet = [.reps: .discrete(8), .weight: .number(25)]
    Form {
        DataSetEditor(exercise: .init(category: .generic(name: "Pull-up", dataTypes: [.reps, .weight], sideType: .none)), dataSet: $dataSet, sides: .single)
    }
}

#Preview("Repeater") {
    @Previewable @State var dataSet: ExerciseData.DataSet = [.reps: .discrete(6)]
    Form {
        DataSetEditor(exercise: .init(category: .repeater(tag: "HC 20mm", timeOn: 7, timeOff: 3)), dataSet: $dataSet, sides: .single)
    }
}

#Preview("Max Hang") {
    @Previewable @State var dataSet: ExerciseData.DataSet = [.time: .discrete(6)]
    Form {
        DataSetEditor(exercise: .init(category: .maxHang(tag: "BM Middle", sideType: .independent)), dataSet: $dataSet, sides: .split)
    }
}

#Preview("Campus") {
    @Previewable @State var dataSet: ExerciseData.DataSet = [:]
    NavigationStack {
        VStack(alignment: .leading, spacing: 8) {
            DataSetEditor(exercise: .init(category: .campus(name: "Basic Ladder", mirrorSets: true)), dataSet: $dataSet, sides: .split)
                .buttonStyle(.glass)
            Spacer()
        }.padding()
    }
}
