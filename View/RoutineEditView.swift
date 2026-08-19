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
                            case .generic:
                                genericView(exercise.generic)
                                    .contentShape(Rectangle())
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
                        Button("Basic") {
                            let exercise = Item.Exercise(.generic(.init()))
                            set.exercises.append(exercise)
                            editExercise = (set.id, exercise.id)
                        }
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
                                case .generic:
                                    return .init(.generic(last.generic))
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
                        Stepper(value: $set.restTime, in: 0...300, step: 30) {
                            Text("Rest Time: \(set.restTime) s")
                        }
                        Picker("", selection: $set.order) {
                            ForEach(Routine.Order.allCases, id: \.name) { order in
                                Text(order.name).tag(order)
                            }
                        }.pickerStyle(.segmented)
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
                case .generic:
                    EditGenericSetsSheet(item: exercise.generic)
                case .repeater:
                    EditRepeaterSetsSheet(item: exercise.repeater)
                case .maxHang:
                    EditMaxHangSetsSheet(item: exercise.maxHang)
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
    
    private func genericView(_ generic: Routine.GenericSets) -> some View {
        VStack(alignment: .leading) {
            Text(generic.name)
                .font(.title3)
                .bold()
            ForEach(generic.sets, id: \.hashValue) { set in
                Text("\(set.text) \(generic.setDetailText)")
            }.font(.subheadline)
                .padding(.leading, 8)
        }
    }
    
    private func repeaterView(_ repeater: Routine.RepeaterSets) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    Text("\(repeater.tag):")
                        .font(.title3)
                        .bold()
                    Text("\(repeater.timeOn)/\(repeater.timeOff) s")
                        .bold()
                }
                ForEach(repeater.sets, id: \.hashValue) { set in
                    Text(set.text)
                }.font(.subheadline)
                    .padding(.leading, 8)
            }
            Spacer()
        }
    }
    
    private func maxHangView(_ maxHang: Routine.MaxHangSets) -> some View {
        VStack(alignment: .leading) {
            Text(maxHang.tag)
                .font(.title3)
                .bold()
            HStack {
                VStack(alignment: .leading) {
                    Text("Left")
                        .underline()
                        .font(.headline)
                    ForEach(maxHang.sets.filter({ $0.side == .left }), id: \.hashValue) { set in
                        Text(set.text)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Right")
                        .underline()
                        .font(.headline)
                    ForEach(maxHang.sets.filter({ $0.side == .right }), id: \.hashValue) { set in
                        Text(set.text)
                    }
                }
            }.font(.subheadline)
        }
    }
    
    struct EditGenericSetsSheet: View {
        @Binding var item: Routine.GenericSets
        @State private var selectionType: SelectionType = .single
        
        var body: some View {
            Form {
                Section {
                    TextField("Name", text: $item.name)
                    Picker("Type", selection: $item.dataType) {
                        ForEach(Routine.GenericSets.DataType.allCases, id: \.name) { type in
                            Text(type.name).tag(type)
                        }
                    }
                    Toggle("Multi-Weight", isOn: .init(get: {
                        item.multiWeight ?? false
                    }, set: { newValue in
                        item.multiWeight = newValue
                    }))
                }
                Section {
                    ForEach($item.sets.enumerated(), id: \.offset) { offset, $set in
                        switch selectionType {
                        case .single:
                            Stepper(value: .init(get: {
                                $set.wrappedValue.min
                            }, set: { newValue in
                                $set.wrappedValue.min = newValue
                                $set.wrappedValue.max = newValue
                            }), in: 1...100, step: 1) {
                                Text("\(set.min) \(item.setDetailText)")
                            }
                        case .range:
                            HStack {
                                Stepper(value: $set.min, in: 1...100, step: 1) {
                                    Text("\(set.min) \(item.setDetailText)")
                                }
                                Stepper(value: $set.max, in: 1...100, step: 1) {
                                    Text("\(set.max) \(item.setDetailText)")
                                }
                            }
                        }
                    }
                } header: {
                    VStack {
                        HStack(spacing: 16) {
                            Text("Sets")
                            Spacer()
                            Button {
                                if let last = item.sets.last {
                                    item.sets.append(.init(min: last.min, max: last.max))
                                } else {
                                    item.sets.append(.init())
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                            Button {
                                item.sets.removeLast()
                            } label: {
                                Image(systemName: "minus")
                            }.disabled(item.sets.isEmpty)
                        }.buttonStyle(.plain)
                        Picker("", selection: $selectionType) {
                            ForEach(SelectionType.allCases, id: \.name) { type in
                                Text(type.name).tag(type)
                            }
                        }.pickerStyle(.segmented)
                    }
                }
            }.presentationDetents([.medium, .large])
        }
        
        enum SelectionType: CaseIterable, Codable, Hashable, Equatable {
            case single, range
            
            var name: String {
                switch self {
                case .single:
                    "Single"
                case .range:
                    "Range"
                }
            }
        }
    }
    
    struct EditRepeaterSetsSheet: View {
        @Binding var item: Routine.RepeaterSets
        
        var body: some View {
            Form {
                Section {
                    TextField("Tag", text: $item.tag)
                } header: {
                    Text("Hold/Grip")
                } footer: {
                    HStack {
                        Stepper("On: \(item.timeOn)s", value: $item.timeOn, in: 0...30)
                        Stepper("Off: \(item.timeOff)s", value: $item.timeOff, in: 0...30)
                    }.bold()
                }
                Section {
                    ForEach($item.sets.enumerated(), id: \.offset) { offset, $set in
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
                            if let last = item.sets.last {
                                item.sets.append(.init(numReps: last.numReps, weight: last.weight))
                            } else {
                                item.sets.append(.init())
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            item.sets.removeLast()
                        } label: {
                            Image(systemName: "minus")
                        }.disabled(item.sets.isEmpty)
                    }.buttonStyle(.plain)
                }
            }.presentationDetents([.medium, .large])
        }
    }
    
    struct EditMaxHangSetsSheet: View {
        @Binding var item: Routine.MaxHangSets
        
        var body: some View {
            Form {
                Section {
                    TextField("Tag", text: $item.tag)
                }
                Section {
                    ForEach($item.sets.filter({ $0.wrappedValue.side == .left }).enumerated(), id: \.offset) { offset, $set in
                        VStack {
                            Stepper("\(set.target)s", value: $set.target, in: 0...30)
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
                        Text("Left")
                        Spacer()
                        Button {
                            if let left = item.sets.filter({ $0.side == .left }).last {
                                item.sets.append(.init(side: .left, target: left.target, weight: left.weight))
                            } else {
                                item.sets.append(.init(side: .left))
                            }
                            if let right = item.sets.filter({ $0.side == .right }).last {
                                item.sets.append(.init(side: .right, target: right.target, weight: right.weight))
                            } else {
                                item.sets.append(.init(side: .right))
                            }
                            
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            item.sets.removeLast(2)
                        } label: {
                            Image(systemName: "minus")
                        }.disabled(item.sets.isEmpty)
                    }.buttonStyle(.plain)
                }
                Section("Right") {
                    ForEach($item.sets.filter({ $0.wrappedValue.side == .right }).enumerated(), id: \.offset) { offset, $set in
                        HStack {
                            Stepper("\(set.target)s", value: $set.target, in: 0...30)
                            Stepper(value: $set.weight, in: -200...200, step: 5) {
                                HStack {
                                    TextField("", value: $set.weight, format: .number.precision(.fractionLength(0...2)))
                                        .keyboardType(.decimalPad)
                                    Text("lbs")
                                }
                            }
                        }
                    }
                }
            }.presentationDetents([.medium, .large])
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
            case .generic:
                .generic(exercise.generic)
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
                    self.order = .bfs
                }
            }
        }
        
        enum ExerciseType {
            case generic, repeater, maxHang
        }
        
        struct Exercise: Identifiable {
            let id: UUID
            var type: ExerciseType
            var generic: Routine.GenericSets = .init()
            var repeater: Routine.RepeaterSets = .init()
            var maxHang: Routine.MaxHangSets = .init()
            
            var invalid: Bool {
                switch type {
                case .generic:
                    generic.name.isEmpty || generic.sets.isEmpty || generic.sets.contains(where: isInvalid)
                case .repeater:
                    repeater.tag.isEmpty || repeater.sets.isEmpty || repeater.sets.contains(where: isInvalid)
                case .maxHang:
                    maxHang.tag.isEmpty || maxHang.sets.isEmpty || maxHang.sets.contains(where: isInvalid)
                }
            }
            
            init(_ exercise: Routine.Exercise) {
                self.id = .init()
                switch exercise {
                case .generic(let d):
                    self.type = .generic
                    self.generic = d
                case .repeater(let d):
                    self.type = .repeater
                    self.repeater = d
                case .maxHang(let d):
                    self.type = .maxHang
                    self.maxHang = d
                }
            }
            
            func isInvalid(_ set: Routine.GenericSet) -> Bool {
                set.min <= 0 || set.max <= 0 || set.min > set.max
            }
            
            func isInvalid(_ set: Routine.RepeaterSet) -> Bool {
                set.numReps <= 0
            }
            
            func isInvalid(_ set: Routine.MaxHangSet) -> Bool {
                set.target <= 0
            }
        }
    }
}

#Preview(traits: .modifier(TestDataModifier())) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineEditView(routine: routines.first!)
    }
}
