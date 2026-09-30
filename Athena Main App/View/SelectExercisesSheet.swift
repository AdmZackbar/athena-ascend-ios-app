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
    @State private var selectedType: ExerciseType = .generic
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
                        List {
                            ForEach(selection, id: \.name) { exercise in
                                exerciseView(exercise, selected: true)
                            }.onDelete { indices in
                                selection.remove(atOffsets: indices)
                            }.onMove { indices, target in
                                selection.move(fromOffsets: indices, toOffset: target)
                            }
                        }
                    }
                }
                if !filter.isEmpty {
                    notSelectedByFilter()
                } else {
                    notSelectedByType()
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
                    ToolbarItemGroup(placement: .primaryAction) {
                        NavigationLink {
                            ExerciseEditView() { newExercise in
                                selection.append(newExercise)
                            }
                        } label: {
                            Label("Add New Exercise", systemImage: "plus")
                        }
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
    
    @ViewBuilder
    func notSelectedByFilter() -> some View {
        let notSelected = exercises.filter { !selection.contains($0) }
            .filter { $0.name.localizedCaseInsensitiveContains(filter) }
            .sorted(by: { $0.name < $1.name })
        if !notSelected.isEmpty {
            let byType: [ExerciseType: [Exercise]] = .init(grouping: notSelected, by: { .from($0.category) })
            ForEach(ExerciseType.allCases, id: \.text) { type in
                if let list = byType[type], !list.isEmpty {
                    Section(type.text) {
                        exerciseListView(list)
                    }
                }
            }
        } else {
            // Show placeholders
            exerciseListView([])
        }
    }
    
    @ViewBuilder
    func notSelectedByType() -> some View {
        Section {
            exerciseListView(exercises.filter { !selection.contains($0) }
                .filter { selectedType == .from($0.category) }
                .sorted(by: { $0.name < $1.name }))
        } header: {
            Picker("Exercise Type", selection: $selectedType) {
                ForEach(ExerciseType.allCases, id: \.text) { t in
                    Text(t.text).tag(t)
                }
            }.pickerStyle(.segmented)
                .padding([.leading, .trailing], -16)
        }
    }
    
    @ViewBuilder
    func exerciseListView(_ list: [Exercise]) -> some View {
        if !list.isEmpty {
            ForEach(list) { exercise in
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
        
        static func from(_ category: Exercise.Category) -> ExerciseType {
            switch category {
            case .generic(_, _, _): return .generic
            case .repeater(_, _, _): return .repeater
            case .maxHang(_, _): return .maxHang
            case .campus(_, _): return .campus
            }
        }
    }
}

#Preview(traits: .sampleData) {
    SelectExercisesSheet() { newSelection in
        // TODO
    }
}
