//
//  ExerciseEditView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/26/26.
//

import SwiftData
import SwiftUI

struct ExerciseEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @Query var existingExercises: [Exercise]
    
    let exercise: Exercise?
    
    @State var draft: Draft
    
    init(exercise: Exercise? = nil) {
        self.exercise = exercise
        var draft: Draft
        switch exercise?.category {
        case .generic(let name, let dataTypes, let sideType):
            draft = .init(type: .generic, name: name, dataTypes: dataTypes, sideType: sideType)
        case .repeater(let tag, let timeOn, let timeOff):
            draft = .init(type: .repeater, name: tag, timeOn: timeOn, timeOff: timeOff)
        case .maxHang(let tag, let sideType):
            draft = .init(type: .maxHang, name: tag, sideType: sideType)
        case .campus(let name, let mirrorSets):
            draft = .init(type: .campus, name: name, mirror: mirrorSets)
        case .none:
            draft = .init(type: .generic, name: "")
        }
        draft.notes = exercise?.notes ?? ""
        // Assign once, don't edit after
        self.draft = draft
    }
    
    var body: some View {
        Form {
            Section {
                switch draft.type {
                case .generic:
                    genericView()
                case .repeater:
                    repeaterView()
                case .maxHang:
                    maxHangView()
                case .campus:
                    campusView()
                }
                stackedView("Notes") {
                    TextField("Optional", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...9)
                }
            } header: {
                Picker("Type", selection: $draft.type) {
                    ForEach(SelectExercisesSheet.ExerciseType.allCases, id: \.text) { type in
                        Text(type.text).tag(type)
                    }
                }.pickerStyle(.segmented)
                    .padding([.leading, .trailing], -16)
            } footer: {
                if draftExists {
                    Text("Exercise already exists!")
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundStyle(.red)
                }
            }
        }.navigationTitle(exercise != nil ? "Edit Exercise" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let exercise {
                            exercise.category = draft.category
                            exercise.notes = draft.notes
                            try? modelContext.save()
                        } else {
                            modelContext.insert(Exercise(category: draft.category, notes: draft.notes))
                        }
                        dismiss()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }.disabled(draft.invalid || draftExists)
                }
            }
    }
    
    @ViewBuilder
    func stackedView<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }
    
    @ViewBuilder
    func genericView() -> some View {
        stackedView("Name") {
            TextField("Required", text: $draft.name)
        }
        stackedView("Data Types", content: dataTypeView)
        stackedView("Sided") {
            Picker("Side Type", selection: $draft.sideType) {
                ForEach(Exercise.SideType.allCases, id: \.hashValue) { s in
                    Text(text(s)).tag(s)
                }
            }.pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    func dataTypeView() -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(Exercise.DataType.allCases, id: \.hashValue) { dataType in
                    if !draft.dataTypes.contains(dataType) {
                        // Add button
                        Button {
                            withAnimation {
                                draft.dataTypes.append(dataType)
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: icon(dataType))
                                    .font(.subheadline)
                                Text(text(dataType))
                                    .font(.caption)
                            }
                        }.buttonStyle(.glass)
                    } else {
                        // Remove button
                        Button {
                            withAnimation {
                                draft.dataTypes.removeAll(where: { $0 == dataType })
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: icon(dataType))
                                    .font(.subheadline)
                                Text(text(dataType))
                                    .font(.caption)
                            }
                        }.buttonStyle(.glassProminent)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func repeaterView() -> some View {
        stackedView("Tag") {
            TextField("Required", text: $draft.name)
        }
        stackedView("Period") {
            HStack(spacing: 8) {
                Stepper("\(draft.timeOn)s on", value: $draft.timeOn, in: 1...99)
                Stepper("\(draft.timeOff)s off", value: $draft.timeOff, in: 1...99)
            }
        }
    }
    
    @ViewBuilder
    func maxHangView() -> some View {
        stackedView("Tag") {
            TextField("Required", text: $draft.name)
        }
        stackedView("Sided") {
            Picker("Side Type", selection: $draft.sideType) {
                ForEach(Exercise.SideType.allCases, id: \.hashValue) { s in
                    Text(text(s)).tag(s)
                }
            }.pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    func campusView() -> some View {
        stackedView("Name") {
            TextField("Required", text: $draft.name)
        }
        Toggle("Mirror Sets", isOn: $draft.mirror)
    }
    
    private func text(_ dataType: Exercise.DataType) -> String {
        switch dataType {
        case .reps: return "Reps"
        case .time: return "Time"
        case .weight: return "Weight"
        case .distance: return "Len."
        }
    }
    
    private func icon(_ dataType: Exercise.DataType) -> String {
        switch dataType {
        case .reps: return "number.sign"
        case .time: return "stopwatch"
        case .weight: return "scalemass"
        case .distance: return "ruler"
        }
    }
    
    private func text(_ sideType: Exercise.SideType) -> String {
        switch sideType {
        case .none: return "N/A"
        case .dependent: return "Dependent"
        case .independent: return "Independent"
        }
    }
    
    var draftExists: Bool {
        let current = draft.category
        return existingExercises.contains(where: { $0.category == current })
    }
    
    struct Draft {
        var type: SelectExercisesSheet.ExerciseType
        var name: String
        var dataTypes: [Exercise.DataType]
        var sideType: Exercise.SideType
        var timeOn: Int
        var timeOff: Int
        var mirror: Bool
        var notes: String
        
        var invalid: Bool {
            switch type {
            case .generic:
                return name.isEmpty || dataTypes.isEmpty
            case .repeater:
                return name.isEmpty || timeOn <= 0 || timeOff <= 0
            case .maxHang, .campus:
                return name.isEmpty
            }
        }
        
        var category: Exercise.Category {
            switch type {
            case .generic:
                return .generic(name: name, dataTypes: dataTypes, sideType: sideType)
            case .repeater:
                return .repeater(tag: name, timeOn: timeOn, timeOff: timeOff)
            case .maxHang:
                return .maxHang(tag: name, sideType: sideType)
            case .campus:
                return .campus(name: name, mirrorSets: mirror)
            }
        }
        
        init(type: SelectExercisesSheet.ExerciseType, name: String, dataTypes: [Exercise.DataType] = [], sideType: Exercise.SideType = .none, timeOn: Int = 5, timeOff: Int = 5, mirror: Bool = true) {
            self.type = type
            self.name = name
            self.dataTypes = dataTypes
            self.sideType = sideType
            self.timeOn = timeOn
            self.timeOff = timeOff
            self.mirror = mirror
            self.notes = ""
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ExerciseEditView()
    }
}
