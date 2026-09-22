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
    @State private var sheetState: SheetState? = nil
    @State private var deleteExercise: (Int, Int)? = nil

    enum SheetState: Identifiable, Hashable {
        case picker(setIndex: Int)
        case edit(setIndex: Int, exerciseIndex: Int)

        var id: String {
            switch self {
            case .picker(let setIndex):
                return "picker-\(setIndex)"
            case .edit(let setIndex, let exerciseIndex):
                return "edit-\(setIndex)-\(exerciseIndex)"
            }
        }
    }
    
    init(routine: Routine? = nil) {
        self.item = .init(routine: routine)
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $item.name)
            ForEach($item.sets.enumerated(), id: \.offset) { offset, $set in
                let setIndex = offset
                Section {
                    ForEach($set.exercises.enumerated(), id: \.offset) { offset, $exercise in
                        let exerciseIndex = offset
                        Button {
                            sheetState = .edit(setIndex: setIndex, exerciseIndex: exerciseIndex)
                        } label: {
                            exerciseView(exercise)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .swipeActions {
                                Button {
                                    deleteExercise = (setIndex, exerciseIndex)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }.tint(.red)
                            }
                    }
                    Menu("Add Exercise") {
                        Button("From Library...") {
                            sheetState = .picker(setIndex: setIndex)
                        }
                        Menu {
                            Button("Basic") {
                                let exercise = Item.Exercise(.generic(.init()))
                                let exerciseIndex = set.exercises.count
                                set.exercises.append(exercise)
                                sheetState = .edit(setIndex: setIndex, exerciseIndex: exerciseIndex)
                            }
                            Button("Repeater") {
                                let exercise = Item.Exercise(.repeater(.init()))
                                let exerciseIndex = set.exercises.count
                                set.exercises.append(exercise)
                                sheetState = .edit(setIndex: setIndex, exerciseIndex: exerciseIndex)
                            }
                            Button("Max Hang") {
                                let exercise = Item.Exercise(.maxHang(.init()))
                                let exerciseIndex = set.exercises.count
                                set.exercises.append(exercise)
                                sheetState = .edit(setIndex: setIndex, exerciseIndex: exerciseIndex)
                            }
                            Button("Campus") {
                                let exercise = Item.Exercise(.campus(.init()))
                                let exerciseIndex = set.exercises.count
                                set.exercises.append(exercise)
                                sheetState = .edit(setIndex: setIndex, exerciseIndex: exerciseIndex)
                            }
                        } label: {
                            Label("New", systemImage: "plus")
                        }
                    }
                } header: {
                    VStack {
                        TextField("Set Name", text: $set.name)
                        Stepper(value: $set.restTime, in: 0...300, step: 15) {
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
        }.sheet(item: $sheetState) { state in
            switch state {
            case .edit(let setIndex, let exerciseIndex):
                let exercise = $item.sets[setIndex].exercises[exerciseIndex]
                switch exercise.wrappedValue.type {
                case .generic:
                    EditGenericSetsSheet(item: exercise.generic)
                case .repeater:
                    EditRepeaterSetsSheet(item: exercise.repeater)
                case .maxHang:
                    EditMaxHangSetsSheet(item: exercise.maxHang)
                case .campus:
                    EditCampusSetsSheet(item: exercise.campus)
                }
            case .picker(let setIndex):
                LibraryPickerView<Exercise> { exercise in
                    guard let routineExercise = ExerciseLibrary.makeRoutineExercise(from: exercise) else { return }
                    exercise.lastUsedAt = .now
                    let exerciseIndex = item.sets[setIndex].exercises.count
                    item.sets[setIndex].exercises.append(.init(routineExercise))
                    sheetState = .edit(setIndex: setIndex, exerciseIndex: exerciseIndex)
                }
            }
        }.navigationTitle(item.routine != nil ? "Edit Routine" : "Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .alert("Delete Exercise?", isPresented: .init(get: {
                deleteExercise != nil
            }, set: { newValue in
                if !newValue {
                    deleteExercise = nil
                }
            })) {
                Button(role: .destructive) {
                    if let deleteExercise {
                        item.sets[deleteExercise.0].exercises.remove(at: deleteExercise.1)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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
    
    @ViewBuilder
    private func exerciseView(_ exercise: Item.Exercise) -> some View {
        switch exercise.type {
        case .generic:
            genericView(exercise.generic)
        case .repeater:
            repeaterView(exercise.repeater)
        case .maxHang:
            maxHangView(exercise.maxHang)
        case .campus:
            campusView(exercise.campus)
        }
    }
    
    private func genericView(_ generic: Routine.GenericSets) -> some View {
        VStack(alignment: .leading) {
            if !generic.name.isEmpty {
                Text(generic.name)
                    .font(.title3)
                    .bold()
            } else {
                Text("No Name")
                    .italic()
            }
            ForEach(generic.sets.enumerated(), id: \.offset) { offset, set in
                Text("\(set.text) \(generic.setDetailText)")
            }.font(.subheadline)
                .padding(.leading, 8)
        }
    }
    
    private func repeaterView(_ repeater: Routine.RepeaterSets) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    if !repeater.tag.isEmpty {
                        Text("\(repeater.tag):")
                    } else {
                        Text("No Tag")
                            .italic()
                            .bold(false)
                    }
                    Text("\(repeater.timeOn)/\(repeater.timeOff) s")
                }.font(.title3).bold()
                ForEach(repeater.sets.enumerated(), id: \.offset) { offset, set in
                    Text(set.text)
                }.font(.subheadline)
                    .padding(.leading, 8)
            }
            Spacer()
        }
    }
    
    private func maxHangView(_ maxHang: Routine.MaxHangSets) -> some View {
        VStack(alignment: .leading) {
            if !maxHang.tag.isEmpty {
                Text("\(maxHang.tag):")
                    .font(.title3)
                    .bold()
            } else {
                Text("No Tag")
                    .italic()
            }
            VStack(alignment: .leading) {
                ForEach(maxHang.sets.enumerated(), id: \.offset) { offset, set in
                    Text(set.text)
                }
            }
        }
    }
    
    private func campusView(_ maxHang: Routine.CampusSets) -> some View {
        VStack(alignment: .leading) {
            Text(maxHang.type.text)
                .font(.title3)
                .bold()
            VStack(alignment: .leading) {
                ForEach(maxHang.sets.enumerated(), id: \.offset) { offset, set in
                    Text(set.text)
                }
            }
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
                    Picker("Sided-ness", selection: $item.sideType) {
                        Text("None").tag(nil as Routine.SideType?)
                        ForEach(Routine.SideType.allCases, id: \.name) { type in
                            Text(type.name).tag(type as Routine.SideType?)
                        }
                    }
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
        @State var multiSide: Bool = true
        
        var body: some View {
            Form {
                Section {
                    TextField("Tag", text: $item.tag)
                }
                Section {
                    ForEach($item.sets.enumerated(), id: \.offset) { offset, $set in
                        if item.isSingleArm && multiSide {
                            HStack {
                                VStack(alignment: .leading, spacing: 16) {
                                    Stepper("\(set.target)s", value: $set.target, in: 0...1000, step: 1)
                                    Stepper(set.weight.lbsFormat, value: $set.weight, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                                }
                                VStack(alignment: .trailing, spacing: 16) {
                                    Stepper("\(set.targetAlt ?? set.target)s", value: .init(get: {
                                        set.targetAlt ?? set.target
                                    }, set: { newValue in
                                        set.targetAlt = newValue
                                    }), in: 0...1000, step: 1)
                                    Stepper((set.weightAlt ?? set.weight).lbsFormat, value: .init(get: {
                                        set.weightAlt ?? set.weight
                                    }, set: { newValue in
                                        set.weightAlt = newValue
                                    }), in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                                }
                            }
                        } else {
                            HStack {
                                Stepper("\(set.target)s", value: $set.target, in: 0...1000, step: 1)
                                Stepper(set.weight.lbsFormat, value: $set.weight, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading) {
                        if item.isSingleArm {
                            Toggle("Different Side Values", isOn: $multiSide)
                        }
                        HStack(spacing: 16) {
                            Text("Sets")
                            Spacer()
                            Button {
                                if let latest = item.sets.last {
                                    item.sets.append(.init(target: latest.target, targetAlt: latest.targetAlt, weight: latest.weight, weightAlt: latest.weightAlt))
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
                }
            }.presentationDetents([.medium, .large])
        }
    }

    struct EditCampusSetsSheet: View {
        @Binding var item: Routine.CampusSets
        @State private var editIndex: Int? = nil
        @State private var campusMoves: [CampusMove] = []
        @State private var campusMoveType: CampusMoveType = .defined

        var body: some View {
            Form {
                if let editIndex {
                    Section {
                        Button {
                            if case .defined = item.sets[editIndex].moves {
                                item.sets[editIndex].moves = .defined(campusMoves)
                            }
                            self.editIndex = nil
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                    CampusPlannedSetEditor(item: $item, index: editIndex, moves: $campusMoves, moveType: $campusMoveType)
                } else {
                    CampusPlannedSetsList(item: $item) { offset in
                        switch item.sets[offset].moves {
                        case .defined(let m):
                            campusMoves = m
                            campusMoveType = .defined
                        default:
                            break
                        }
                        editIndex = offset
                    }
                }
            }.presentationDetents([.medium, .large])
        }
    }

    private struct Item {
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
            var routineSets = sets.map(toRoutineSet)
            // Exercises added via the "New" submenu aren't in the library yet — link
            // them now rather than on creation, so an exercise added and immediately
            // deleted never litters the library.
            for setIndex in routineSets.indices {
                for exIndex in routineSets[setIndex].exercises.indices {
                    guard routineSets[setIndex].exercises[exIndex].exerciseID == nil,
                          let exercise = ExerciseLibrary.findOrCreate(for: routineSets[setIndex].exercises[exIndex], in: modelContext)
                    else { continue }
                    routineSets[setIndex].exercises[exIndex].exerciseID = exercise.uuid
                }
            }
            if let routine {
                routine.name = name
                routine.sets = routineSets
                // Keep every session's name snapshot in sync while the routine still
                // exists. Unlike an Exercise's prescription, a routine's name has
                // nothing to "diverge" from, so there's no reason to freeze it early.
                for session in routine.sessions {
                    session.routineName = name
                }
            } else {
                let newRoutine = Routine(name: name, sets: routineSets)
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
            case .campus:
                .campus(exercise.campus)
            }
        }
        
        struct Set {
            var name: String
            var exercises: [Exercise]
            var restTime: Int
            var order: Routine.Order
            
            var invalid: Bool {
                name.isEmpty || restTime < 0 || exercises.contains(where: \.invalid)
            }
            
            init(_ set: Routine.ExerciseSet? = nil) {
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
            case generic, repeater, maxHang, campus
        }
        
        struct Exercise {
            var type: ExerciseType
            var generic: Routine.GenericSets = .init()
            var repeater: Routine.RepeaterSets = .init()
            var maxHang: Routine.MaxHangSets = .init()
            var campus: Routine.CampusSets = .init()
            
            var invalid: Bool {
                switch type {
                case .generic:
                    generic.name.isEmpty || generic.sets.isEmpty || generic.sets.contains(where: isInvalid)
                case .repeater:
                    repeater.tag.isEmpty || repeater.sets.isEmpty || repeater.sets.contains(where: isInvalid)
                case .maxHang:
                    maxHang.tag.isEmpty || maxHang.sets.isEmpty || maxHang.sets.contains(where: isInvalid)
                case .campus:
                    campus.sets.isEmpty || campus.sets.contains(where: isInvalid)
                }
            }
            
            init(_ exercise: Routine.Exercise) {
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
                case .campus(let d):
                    self.type = .campus
                    self.campus = d
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

            func isInvalid(_ set: Routine.CampusSets.PlannedSet) -> Bool {
                if case .defined(let moves) = set.moves {
                    return moves.count < 2
                }
                return false
            }
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineEditView(routine: routines.first!)
    }
}
