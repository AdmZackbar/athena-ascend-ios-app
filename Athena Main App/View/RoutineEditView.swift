//
//  RoutineEditView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftData
import SwiftUI

struct RoutineEditView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    @State private var routine: Routine
    @State private var isNew: Bool
    @State private var sheetType: SheetType? = nil
    @State private var deleteSuperIndex: Int? = nil
    @State private var deleteExercise: ExerciseData.Position? = nil
    
    init(routine: Routine? = nil) {
        self.routine = routine ?? .init(superSets: [.init(name: "")])
        self.isNew = routine == nil
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $routine.name)
            }
            ForEach($routine.superSets.enumerated(), id: \.offset) { offset, $superSet in
                Section {
                    ForEach(routine.data
                        .filter { $0.position.superSetIndex == offset }
                        .sorted(by: { $0.position < $1.position })) { data in
                            Button {
                                sheetType = .editData(data)
                            } label: {
                                HStack {
                                    RoutineDataEntryView(data: data)
                                    Spacer()
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteExercise = data.position
                                    } label: {
                                        Label("Remove Exercise", systemImage: "trash")
                                    }
                                }
                    }
                    Button {
                        sheetType = .addExercise(offset)
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        TextField("Name", text: $superSet.name, prompt: Text("Set \(offset + 1)"))
                        Spacer()
                        Picker("Order", selection: $superSet.order) {
                            ForEach(Routine.SuperSet.Order.allCases, id: \.name) { order in
                                Text(order.name).tag(order)
                            }
                        }
                        Button(role: .destructive) {
                            deleteSuperIndex = offset
                        } label: {
                            Label("Delete Super Set", systemImage: "trash")
                                .labelStyle(.iconOnly)
                        }.buttonStyle(.glassProminent)
                    }
                } footer: {
                    Stepper(superSet.restTime > 0 ? "Rest: \(superSet.restTime)s" : "No Rest", value: $superSet.restTime)
                }
            }
        }.navigationTitle("Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Super Set?", isPresented: .init(get: {
                deleteSuperIndex != nil
            }, set: { newValue in
                if !newValue {
                    deleteSuperIndex = nil
                }
            })) {
                Button("Delete", role: .destructive) {
                    if let deleteSuperIndex {
                        routine.superSets.remove(at: deleteSuperIndex)
                        // Remove exercise data
                        routine.data.removeAll(where: { $0.position.superSetIndex == deleteSuperIndex })
                        // Update position indices
                        routine.data
                            .filter { $0.position.superSetIndex > deleteSuperIndex }
                            .forEach { $0.position = .init(superSetIndex: $0.position.superSetIndex - 1, setIndex: $0.position.setIndex) }
                    }
                }
            }
            .alert("Delete Exercise?", isPresented: .init(get: {
                deleteExercise != nil
            }, set: { newValue in
                if !newValue {
                    deleteExercise = nil
                }
            })) {
                Button("Delete", role: .destructive) {
                    if let deleteExercise {
                        routine.data.removeAll(where: { $0.position == deleteExercise })
                        // Update positions of all later exercises to reflect the shift down
                        routine.data
                            .filter { $0.position.superSetIndex == deleteExercise.superSetIndex && $0.position.setIndex > deleteExercise.setIndex }
                            .forEach { $0.position = .init(superSetIndex: $0.position.superSetIndex, setIndex: $0.position.setIndex - 1) }
                    }
                }
            }
            .sheet(isPresented: .init(get: {
                sheetType != nil
            }, set: { newValue in
                if !newValue {
                    sheetType = nil
                }
            })) {
                switch sheetType {
                case .addExercise(let superSetIndex):
                    let initialSelection = Set(routine.data
                        .filter { $0.position.superSetIndex == superSetIndex }
                        .compactMap { $0.exercise })
                        .sorted(by: { $0.name < $1.name })
                    SelectExercisesSheet(initialSelection: initialSelection) { newSelection in
                        let newExercises = newSelection.filter { !initialSelection.contains($0) }
                        let removedExercises = initialSelection.filter { !newSelection.contains($0) }
                        // Remove all data for the removed exercises
                        routine.data.removeAll(where: { removedExercises.contains($0.exercise) })
                        // Add athlete placeholder data
                        let nextSetIndex: Int = routine.data
                            .filter { $0.position.superSetIndex == superSetIndex }
                            .map { $0.position.setIndex }
                            .max() ?? 0
                        routine.data += newExercises.enumerated().map { offset, exercise in
                            RoutineData(exercise: exercise, routine: routine, position: .init(superSetIndex: superSetIndex, setIndex: nextSetIndex + offset))
                        }
                    }
                case .editData(let data):
                    RoutineDataEditSheet(data: data)
                case nil:
                    EmptyView()
                }
            }
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                routine.superSets.append(.init(name: ""))
            } label: {
                Label("Add New Super Set", systemImage: "plus")
            }
        }
    }
    
    enum SheetType: Hashable {
        case addExercise(_ superSetIndex: Int)
        case editData(_ data: RoutineData)
    }
}

#Preview("Existing", traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineEditView(routine: routines.first!)
    }
}

#Preview("Fresh", traits: .sampleData) {
    NavigationStack {
        RoutineEditView()
    }
}
