//
//  RoutineDataEditSheet.swift
//  Athena
//
//  Created by Zach Wassynger on 9/26/26.
//

import SwiftData
import SwiftUI

struct RoutineDataEditSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let data: RoutineData
    
    var canMirror: Bool {
        switch data.exercise.category {
        case .generic(_, _, let sideType): return sideType == .independent
        case .repeater(_, _, _): return false
        case .maxHang(_, let sideType): return sideType == .independent
        case .campus(_, let mirrorSets): return mirrorSets
        }
    }
    
    @State private var dataSets: [ExerciseData.DataSet]
    @State private var showAlt: Bool
    @State private var discreteStep: Int = 1
    @State private var numberStep: Double = 5
    
    init(data: RoutineData) {
        self.data = data
        self.dataSets = data.expectedData
        self.showAlt = data.expectedData.contains(where: { $0.hasAlt })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                ForEach(0..<dataSets.count, id: \.self) { setIndex in
                    Section {
                        editor(setIndex: setIndex)
                        TextField("Notes", text: .init(get: {
                            getString(setIndex, field: .notes)
                        }, set: { newValue in
                            if newValue.isEmpty {
                                dataSets[setIndex].removeValue(forKey: .notes)
                            } else {
                                dataSets[setIndex][.notes] = .text(newValue)
                            }
                        })).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        HStack {
                            Text("Set \(setIndex + 1)")
                                .bold()
                            Spacer()
                            Button(role: .destructive) {
                                // TODO confirm
                                dataSets.remove(at: setIndex)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                Button {
                    dataSets.append(.init())
                } label: {
                    Label("Add Set", systemImage: "plus")
                }
            }.navigationTitle(data.exercise.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: toolbarContent)
        }.presentationDetents([.large])
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Menu("Unit Step Size") {
                    ForEach([1, 5, 10], id: \.self) { step in
                        Button("\(step.formatted()) units") {
                            numberStep = step
                        }.disabled(numberStep == step)
                    }
                }
                Menu("Weight Step Size") {
                    ForEach([1, 2.5, 5, 10], id: \.self) { step in
                        Button("\(step.formatted(.number.precision(.fractionLength(0...1)))) lbs") {
                            numberStep = step
                        }.disabled(numberStep == step)
                    }
                }
            } label: {
                Label("Options", systemImage: "gear")
            }
            if canMirror {
                Button {
                    showAlt.toggle()
                } label: {
                    Image(systemName: showAlt ? "square.lefthalf.filled" : "square")
                }
            }
            Button {
                data.expectedData = dataSets.map { dataSet in
                    if canMirror && !showAlt {
                        // Strip out all alt values
                        return dataSet.filter { !$0.key.isAlt }
                    } else if showAlt {
                        // Remove all dupe alt values
                        return dataSet.dedupe()
                    }
                    return dataSet
                }
                dismiss()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
        }
    }
    
    @ViewBuilder
    func editor(setIndex: Int) -> some View {
        switch data.exercise.category {
        case .generic(_, let dataTypes, _):
            // Force consistent order
            ForEach(Exercise.DataType.allCases.enumerated(), id: \.offset) { offset, dataType in
                if dataTypes.contains(dataType) {
                    stepperGroup(setIndex, dataType: dataType)
                }
            }
        case .repeater(_, _, _):
            stepperGroup(setIndex, dataType: .reps)
            stepperGroup(setIndex, dataType: .weight)
        case .maxHang(_, _):
            stepperGroup(setIndex, dataType: .time)
            stepperGroup(setIndex, dataType: .weight)
        case .campus(_, _):
            Text("TODO")
        }
    }
    
    @ViewBuilder
    func stepperGroup(_ setIndex: Int, dataType: Exercise.DataType) -> some View {
        if showAlt {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    stepper(setIndex, dataType: dataType)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    stepper(setIndex, dataType: dataType, alt: true)
                }
            }
        } else if canMirror {
            VStack(alignment: .leading, spacing: 2) {
                Text("Both")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                stepper(setIndex, dataType: dataType)
            }
        } else {
            stepper(setIndex, dataType: dataType)
        }
    }
    
    @ViewBuilder
    func stepper(_ setIndex: Int, dataType: Exercise.DataType, alt: Bool = false) -> some View {
        switch dataType {
        case .reps, .time, .distance:
            Stepper(dataSets[setIndex].getText(dataType, useAlt: alt) ?? "0\(dataType.getUnit(0))", value: .init(get: {
                if alt, let altValue = getInt(setIndex, field: dataType.altField) {
                    return altValue
                }
                return getInt(setIndex, field: dataType.field) ?? 0
            }, set: { newValue in
                setValue(setIndex, dataType: dataType, alt: alt, value: .discrete(newValue))
            }), in: 0...999, step: discreteStep)
        case .weight:
            Stepper(dataSets[setIndex].getText(dataType, useAlt: alt) ?? "0 lbs", value: .init(get: {
                if alt, let altValue = getDouble(setIndex, field: dataType.altField) {
                    return altValue
                }
                return getDouble(setIndex, field: dataType.field) ?? 0
            }, set: { newValue in
                setValue(setIndex, dataType: dataType, alt: alt, value: .number(newValue))
            }), in: 0...999, step: numberStep, format: .number.precision(.fractionLength(0...1)))
        }
    }
    
    private func getInt(_ setIndex: Int, field: ExerciseData.Field) -> Int? {
        switch dataSets[setIndex][field] {
        case .discrete(let v): return v
        default: return nil
        }
    }
    
    private func getDouble(_ setIndex: Int, field: ExerciseData.Field) -> Double? {
        switch dataSets[setIndex][field] {
        case .number(let v): return v
        default: return nil
        }
    }
    
    private func getString(_ setIndex: Int, field: ExerciseData.Field) -> String {
        switch dataSets[setIndex][field] {
        case .text(let str): return str
        default: return ""
        }
    }
    
    private func setValue(_ setIndex: Int, dataType: Exercise.DataType, alt: Bool, value: ExerciseData.Value) {
        if alt {
            dataSets[setIndex][dataType.altField] = value
        } else {
            dataSets[setIndex][dataType.field] = value
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    RoutineDataEditSheet(data: routines.first!.data.first!)
}
