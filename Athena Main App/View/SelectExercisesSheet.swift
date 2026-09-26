//
//  SelectExercisesSheet.swift
//  Athena
//
//  Created by Zach Wassynger on 9/26/26.
//

import SwiftData
import SwiftUI

struct SelectExercisesSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @Query private var exercises: [Exercise]
    
    let initialSelection: [Exercise]
    let onComplete: ([Exercise]) -> Void
    @State var selection: [Exercise]
    @State private var selectedType: ExerciseType? = nil
    @State private var filter: String = ""
    
    init(initialSelection: [Exercise] = [], onComplete: @escaping ([Exercise]) -> Void) {
        self.initialSelection = initialSelection
        self.onComplete = onComplete
        self.selection = initialSelection
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Selection") {
                    if selection.isEmpty {
                        Text("No Selection")
                            .italic()
                    } else {
                        ForEach(selection.sorted(by: { $0.name < $1.name }).enumerated(), id: \.offset) { offset, exercise in
                            Button {
                                selection.remove(at: offset)
                            } label: {
                                exerciseView(exercise, selected: true)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                let notSelected = exercises.filter { !selection.contains($0) }
                    .filter { selectedType == nil || selectedType!.hasType($0) }
                    .filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
                    .sorted(by: { $0.name < $1.name })
                Section {
                    if !notSelected.isEmpty {
                        ForEach(notSelected) { exercise in
                            Button {
                                selection.append(exercise)
                            } label: {
                                exerciseView(exercise, selected: false)
                            }.buttonStyle(.plain)
                        }
                    } else if exercises.isEmpty {
                        ContentUnavailableView("No exercises in database", systemImage: "tablecells")
                    } else if exercises.filter({ !selection.contains($0) }).isEmpty {
                        ContentUnavailableView("All exercises selected", systemImage: "checkmark")
                    } else {
                        ContentUnavailableView("No remaining exercises match filters", systemImage: "line.3.horizontal.decrease")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        Picker("Exercise Type", selection: $selectedType) {
                            Text("All").tag(nil as ExerciseType?)
                            ForEach(ExerciseType.allCases, id: \.text) { t in
                                Text(t.text).tag(t as ExerciseType?)
                            }
                        }
                    }
                }
                
            }.navigationTitle("Select Exercise(s)")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $filter)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            onComplete(selection)
                            dismiss()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }.disabled(selection.isEmpty || selection == initialSelection)
                    }
                }
        }.presentationDetents([.large])
    }
    
    @ViewBuilder
    func exerciseView(_ exercise: Exercise, selected: Bool) -> some View {
        HStack {
            Label(exercise.name, systemImage: selected ? "checkmark.circle" : "circle")
                .bold(selected && !initialSelection.contains(exercise))
                .strikethrough(!selected && initialSelection.contains(exercise))
            Spacer()
        }.contentShape(Rectangle())
    }
    
    enum ExerciseType: CaseIterable {
        case generic
        case repeater
        case maxHang
        case campus
        
        var text: String {
            switch self {
            case .generic: "Generic"
            case .repeater: "Repeater"
            case .maxHang: "Max Hang"
            case .campus: "Campus"
            }
        }
        
        func hasType(_ exercise: Exercise) -> Bool {
            switch exercise.category {
            case .generic(_, _, _):
                return self == .generic
            case .repeater(_, _, _):
                return self == .repeater
            case .maxHang(_, _):
                return self == .maxHang
            case .campus(_, _):
                return self == .campus
            }
        }
    }
}

#Preview(traits: .sampleData) {
    SelectExercisesSheet() { newSelection in
        // TODO
    }
}
