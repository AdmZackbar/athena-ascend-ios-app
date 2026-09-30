//
//  DataSetEditor.swift
//  Athena
//
//  Created by Zach Wassynger on 9/29/26.
//

import SwiftUI

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
            let resolved = (alt ? getInt(dataType.altField) ?? getInt(dataType.field) : getInt(dataType.field)) ?? 0
            Stepper("\(resolved.formatted())\(dataType.getUnit(resolved))", value: .init(get: {
                resolved
            }, set: { newValue in
                dataSet[dataType.getField(alt: alt)] = .discrete(newValue)
            }), in: 0...999, step: discreteStep)
        case .weight:
            let resolved = (alt ? getDouble(dataType.altField) ?? getDouble(dataType.field) : getDouble(dataType.field)) ?? 0
            Stepper("\(resolved.formatted(.number.precision(.fractionLength(0...1)))) lbs", value: .init(get: {
                resolved
            }, set: { newValue in
                dataSet[dataType.getField(alt: alt)] = .number(newValue)
            }), in: 0...999, step: numberStep, format: .number.precision(.fractionLength(0...1)))
        }
    }

    @ViewBuilder
    private func campusEditor(alt: Bool) -> some View {
        let current: CampusSet = {
            if alt {
                return getCampusSet(.campusAlt) ?? getCampusSet(.campus)?.flipped() ?? .init(board: .largeEdges, moves: [])
            } else {
                return getCampusSet(.campus) ?? .init(board: .largeEdges, moves: [])
            }
        }()
        NavigationLink {
            CampusBoardView(set: current) { newSet in
                dataSet[alt ? .campusAlt : .campus] = .campus(newSet)
            }
        } label: {
            Text(current.moves.text)
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

#Preview {
    @Previewable @State var dataSet: ExerciseData.DataSet = [.reps: .discrete(8), .weight: .number(25)]
    Form {
        DataSetEditor(exercise: .init(category: .generic(name: "Pull-up", dataTypes: [.reps, .weight], sideType: .none)), dataSet: $dataSet, sides: .single)
    }
}
