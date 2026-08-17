//
//  RoutineEditView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftData
import SwiftUI

struct RoutineEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var item: Item
    @State private var editExercise: (UUID, UUID)? = nil
    
    init(routine: Routine? = nil) {
        self.item = .init(routine: routine)
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $item.name)
            ForEach($item.sets) { $set in
                Section {
                    ForEach($set.exercises) { $exercise in
                        Button {
                            editExercise = (set.id, exercise.id)
                        } label: {
                            switch exercise.type {
                            case .repeater:
                                repeaterView(exercise.repeater)
                                    .contentShape(Rectangle())
                            case .maxHang:
                                maxHangView(exercise.maxHang)
                                    .contentShape(Rectangle())
                            }
                            
                        }.buttonStyle(.plain)
                        
                    }
                    Menu("Add Exercise") {
                        Button("Repeater") {
                            let exercise = Item.Exercise(.repeater(.init()))
                            set.exercises.append(exercise)
                            editExercise = (set.id, exercise.id)
                        }
                        Button("Max Hang") {
                            let exercise = Item.Exercise(.maxHang(.init()))
                            set.exercises.append(exercise)
                            editExercise = (set.id, exercise.id)
                        }
                        Button("Copy Last") {
                            var exercise: Item.Exercise {
                                let last = set.exercises.last!
                                switch last.type {
                                case .repeater:
                                    return .init(.repeater(last.repeater))
                                case .maxHang:
                                    return .init(.maxHang(last.maxHang))
                                }
                            }
                            set.exercises.append(exercise)
                            // TODO why crash?
//                            editExercise = (set.id, exercise.id)
                        }.disabled(set.exercises.isEmpty)
                    }
                } header: {
                    VStack {
                        TextField("Set Name", text: $set.name)
                        Picker("Order:", selection: $set.order) {
                            ForEach(Routine.Order.allCases, id: \.name) { order in
                                Text(order.name).tag(order)
                            }
                        }.pickerStyle(.segmented)
                        Stepper(value: $set.restTime, in: 0...300, step: 30) {
                            Text("Rest Time: \(set.restTime) s")
                        }
                    }
                }
            }
            Button {
                item.sets.append(.init())
            } label: {
                Label("Add Set", systemImage: "plus")
            }
        }.sheet(isPresented: .init(get: {
            editExercise != nil
        }, set: { newValue in
            if !newValue {
                editExercise = nil
            }
        })) {
            if let editExercise {
                let exercise = $item.sets.filter { $0.id == editExercise.0 }.first!
                    .exercises.filter { $0.id == editExercise.1 }.first!
                switch exercise.wrappedValue.type {
                case .repeater:
                    EditRepeaterSheet(item: exercise.repeater)
                case .maxHang:
                    EditMaxHangSheet(item: exercise.maxHang)
                }
            }
        }.navigationTitle(item.routine != nil ? "Edit Routine" : "Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        item.save(modelContext)
                        dismiss()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }.disabled(!item.isEdited || item.invalid)
                }
            }
    }
    
    private func repeaterView(_ repeater: Routine.Repeater) -> some View {
        HStack {
            Text(repeater.tag)
            Text("\(repeater.timeOn)/\(repeater.timeOff) s x\(repeater.numReps)")
            Text("\(repeater.weight.formatted(.number.precision(.fractionLength(0...2)))) lb")
        }
    }
    
    private func maxHangView(_ maxHang: Routine.MaxHang) -> some View {
        HStack {
            Text(maxHang.tag)
            Text(maxHang.side.abbreviation)
            Text("Target: \(maxHang.target)s")
            Text("\(maxHang.weight.formatted(.number.precision(.fractionLength(0...2)))) lb")
        }
    }
    
    struct EditRepeaterSheet: View {
        @Binding var item: Routine.Repeater
        
        var body: some View {
            Form {
                Section {
                    Stepper("\(item.numReps) reps", value: $item.numReps, in: 1...30)
                    Stepper("Time On: \(item.timeOn)s", value: $item.timeOn, in: 0...30)
                    Stepper("Time Off: \(item.timeOff)s", value: $item.timeOff, in: 0...30)
                    Stepper(value: $item.weight, in: -200...200, step: 5) {
                        HStack {
                            Button {
                                item.weight = -item.weight
                            } label: {
                                Text("Weight:")
                            }.buttonStyle(.glass)
                            TextField("", value: $item.weight, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }
                } header: {
                    TextField("Tag", text: $item.tag)
                }
            }.presentationDetents([.height(300), .medium])
        }
    }
    
    struct EditMaxHangSheet: View {
        @Binding var item: Routine.MaxHang
        
        var body: some View {
            Form {
                Section {
                    Picker("Side", selection: $item.side) {
                        ForEach(Routine.Side.allCases, id: \.name) { side in
                            Text(side.name).tag(side)
                        }
                    }.pickerStyle(.segmented)
                    Stepper("Target: \(item.target)s", value: $item.target, in: 0...30)
                    Stepper(value: $item.weight, in: -200...200, step: 5) {
                        HStack {
                            Button {
                                item.weight = -item.weight
                            } label: {
                                Text("Weight:")
                            }.buttonStyle(.glass)
                            TextField("", value: $item.weight, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }
                } header: {
                    TextField("Tag", text: $item.tag)
                }
            }.presentationDetents([.height(280), .medium])
        }
    }
    
    private struct Item: Identifiable {
        let id: UUID
        var routine: Routine?
        var name: String
        var sets: [Set]
        
        var isEdited: Bool {
            if let routine {
                return routine.name != name || !routine.sets.elementsEqual(sets.map(toRoutineSet))
            } else {
                return true
            }
        }
        
        var invalid: Bool {
            name.isEmpty || sets.contains(where: \.invalid)
        }
        
        init(routine: Routine? = nil) {
            self.id = .init()
            self.routine = routine
            if let routine {
                self.name = routine.name
                self.sets = routine.sets.map({ Set($0) })
            } else {
                self.name = ""
                self.sets = []
            }
        }
        
        mutating func save(_ modelContext: ModelContext) {
            if let routine {
                routine.name = name
                routine.sets = sets.map(toRoutineSet)
            } else {
                let newRoutine = Routine(name: name, sets: sets.map(toRoutineSet))
                self.routine = newRoutine
                modelContext.insert(newRoutine)
            }
        }
        
        func toRoutineSet(_ set: Set) -> Routine.ExerciseSet {
            .init(name: set.name, exercises: set.exercises.map(toRoutineExercise), restTime: set.restTime, order: set.order)
        }
        
        func toRoutineExercise(_ exercise: Exercise) -> Routine.Exercise {
            switch exercise.type {
            case .repeater:
                .repeater(exercise.repeater)
            case .maxHang:
                .maxHang(exercise.maxHang)
            }
        }
        
        struct Set: Identifiable {
            let id: UUID
            var name: String
            var exercises: [Exercise]
            var restTime: Int
            var order: Routine.Order
            
            var invalid: Bool {
                name.isEmpty || restTime < 0 || exercises.contains(where: \.invalid)
            }
            
            init(_ set: Routine.ExerciseSet? = nil) {
                self.id = .init()
                if let set {
                    self.name = set.name
                    self.exercises = set.exercises.map({ Exercise($0) })
                    self.restTime = set.restTime
                    self.order = set.order
                } else {
                    self.name = ""
                    self.exercises = []
                    self.restTime = 0
                    self.order = .parallel
                }
            }
        }
        
        enum ExerciseType {
            case repeater, maxHang
        }
        
        struct Exercise: Identifiable {
            let id: UUID
            var type: ExerciseType
            var repeater: Routine.Repeater
            var maxHang: Routine.MaxHang
            
            var invalid: Bool {
                switch type {
                case .repeater:
                    repeater.tag.isEmpty || repeater.numReps <= 0
                case .maxHang:
                    maxHang.tag.isEmpty || maxHang.target <= 0
                }
            }
            
            init(_ exercise: Routine.Exercise) {
                self.id = .init()
                switch exercise {
                case .repeater(let r):
                    self.type = .repeater
                    self.repeater = r
                    self.maxHang = .init()
                case .maxHang(let m):
                    self.type = .maxHang
                    self.maxHang = m
                    self.repeater = .init()
                }
            }
        }
    }
}

#Preview {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineEditView(routine: routines.first!)
    }
}
