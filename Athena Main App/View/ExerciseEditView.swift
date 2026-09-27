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
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...9)
            } header: {
                Picker("Type", selection: $draft.type) {
                    ForEach(SelectExercisesSheet.ExerciseType.allCases, id: \.text) { type in
                        Text(type.text).tag(type)
                    }
                }.pickerStyle(.segmented)
                    .padding([.leading, .trailing], -16)
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
                    }.disabled(draft.invalid)
                }
            }
    }
    
    @ViewBuilder
    func genericView() -> some View {
        TextField("Name", text: $draft.name)
        ForEach(Exercise.DataType.allCases, id: \.hashValue) { dataType in
            Toggle(text(dataType), isOn: .init(get: {
                draft.dataTypes.contains(dataType)
            }, set: { newValue in
                if newValue {
                    draft.dataTypes.append(dataType)
                } else {
                    draft.dataTypes.removeAll(where: { $0 == dataType })
                }
            }))
        }
        Picker("Side Type", selection: $draft.sideType) {
            ForEach(Exercise.SideType.allCases, id: \.hashValue) { s in
                Text(text(s)).tag(s)
            }
        }
    }
    
    @ViewBuilder
    func repeaterView() -> some View {
        TextField("Tag", text: $draft.name)
        Stepper("Time On: \(draft.timeOn)s", value: $draft.timeOn, in: 1...99)
        Stepper("Time Off: \(draft.timeOff)s", value: $draft.timeOff, in: 1...99)
    }
    
    @ViewBuilder
    func maxHangView() -> some View {
        TextField("Tag", text: $draft.name)
        Picker("Side Type", selection: $draft.sideType) {
            ForEach(Exercise.SideType.allCases, id: \.hashValue) { s in
                Text(text(s)).tag(s)
            }
        }
    }
    
    @ViewBuilder
    func campusView() -> some View {
        TextField("Name", text: $draft.name)
        Toggle("Mirror Sets", isOn: $draft.mirror)
    }
    
    private func text(_ dataType: Exercise.DataType) -> String {
        switch dataType {
        case .reps: return "Reps"
        case .time: return "Time"
        case .weight: return "Weight"
        case .distance: return "Height"
        }
    }
    
    private func text(_ sideType: Exercise.SideType) -> String {
        switch sideType {
        case .none: return "N/A"
        case .dependent: return "Dependent"
        case .independent: return "Independent"
        }
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
