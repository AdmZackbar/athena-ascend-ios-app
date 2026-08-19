//
//  SessionExerciseSheet.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/19/26.
//

import SwiftUI

struct SessionExerciseSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var exercise: Session.Exercise
    @State private var editType: EditType = .Exercise
    @State private var repeater: Routine.RepeaterSets
    @State private var repeaterData: [Session.RepeaterSet]
    @State private var notes: String
    
    init(exercise: Binding<Session.Exercise>) {
        self._exercise = exercise
        switch exercise.wrappedValue {
        case .repeater(let d):
            repeater = d.expected
            repeaterData = d.actual
            notes = d.notes
        default:
            repeater = .init()
            repeaterData = []
            notes = ""
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                switch editType {
                case .Exercise:
                    switch exercise {
                    case .repeater(_):
                        repeaterExerciseView()
                    default:
                        Text("TODO")
                    }
                case .Data:
                    switch exercise {
                    case .repeater(_):
                        repeaterDataView()
                    default:
                        Text("TODO")
                    }
                }
                
            }.navigationTitle("Edit Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("", selection: $editType) {
                            ForEach(EditType.allCases, id: \.rawValue) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }.pickerStyle(.segmented)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: save) {
                            Label("Save", systemImage: "checkmark")
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
        }.presentationDetents([.medium, .large])
    }
    
    func save() {
        switch exercise {
        case .repeater(_):
            exercise = .repeater(.init(expected: repeater, actual: repeaterData, notes: notes))
        default:
            // TODO
            break
        }
        dismiss()
    }
    
    @ViewBuilder
    func repeaterExerciseView() -> some View {
        Section {
            TextField("Tag", text: $repeater.tag)
        } header: {
            Text("Hold/Grip")
        } footer: {
            HStack {
                Stepper("On: \(repeater.timeOn)s", value: $repeater.timeOn, in: 0...30)
                Stepper("Off: \(repeater.timeOff)s", value: $repeater.timeOff, in: 0...30)
            }.bold()
        }
        Section {
            ForEach($repeater.sets.enumerated(), id: \.offset) { offset, $set in
                HStack {
                    Stepper("\(set.numReps) reps", value: $set.numReps, in: 1...30)
                    Stepper(value: $set.weight, in: -200...200, step: 5) {
                        HStack {
                            TextField("", value: $set.weight, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }
                }
            }
        } header: {
            HStack(spacing: 16) {
                Text("Sets")
                Spacer()
                Button {
                    if let last = repeater.sets.last {
                        repeater.sets.append(.init(numReps: last.numReps, weight: last.weight))
                    } else {
                        repeater.sets.append(.init())
                    }
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    repeater.sets.removeLast()
                    if repeaterData.count > repeater.sets.count {
                        repeaterData.removeLast()
                    }
                } label: {
                    Image(systemName: "minus")
                }.disabled(repeater.sets.isEmpty)
            }.buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    func repeaterDataView() -> some View {
        Section {
            ForEach($repeaterData.enumerated(), id: \.offset) { offset, $set in
                VStack {
                    HStack {
                        Stepper("\(set.numReps) reps", value: $set.numReps, in: 0...30, step: 1)
                        Stepper(set.weight.lbsFormat, value: $set.weight, in: -200...200, step: 5, format: .number.precision(.fractionLength(0...2)))
                    }
                    TextField("Notes", text: $set.notes, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
        } header: {
            HStack {
                Text("Sets")
                Spacer()
                Button("Add") {
                    repeaterData.append(.init())
                }.disabled(repeaterData.count >= repeater.sets.count)
                Button("Remove") {
                    repeaterData.removeLast()
                }.disabled(repeaterData.isEmpty)
            }
        }
        Section("Notes") {
            TextField("optional", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    enum EditType: String, CaseIterable, Codable, Hashable, Equatable {
        case Exercise, Data
    }
}
