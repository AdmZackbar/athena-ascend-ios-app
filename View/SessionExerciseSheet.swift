//
//  SessionExerciseSheet.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/19/26.
//

import SwiftUI

struct SessionExerciseSheet: View {
    typealias SelectionType = RoutineEditView.EditGenericSetsSheet.SelectionType
    
    @Binding var exercise: Session.Exercise
    @Binding var showing: Bool
    @State private var editType: EditType = .Data
    @State private var selectionType: SelectionType = .single
    @State private var generic: Routine.GenericSets = .init()
    @State private var repeater: Routine.RepeaterSets = .init()
    @State private var maxHang: Routine.MaxHangSets = .init()
    @State private var data: [RoutineSessionView.GenericDataSet]
    @State private var notes: String
    @State private var multiSide: Bool
    
    init(exercise: Binding<Session.Exercise>, showing: Binding<Bool>) {
        self._exercise = exercise
        self._showing = showing
        switch exercise.wrappedValue {
        case .generic(let d):
            generic = d.expected
            data = d.actual.map({ .init($0, format: d.expected) })
            notes = d.notes
            multiSide = d.actual.contains(where: \.hasDiffSideData)
        case .repeater(let d):
            repeater = d.expected
            data = d.actual.map({ .init($0) })
            notes = d.notes
            multiSide = false
        case .maxHang(let d):
            maxHang = d.expected
            data = d.actual.map({ .init($0) })
            notes = d.notes
            multiSide = false
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                switch exercise {
                case .generic(_):
                    genericView()
                case .repeater(_):
                    repeaterView()
                case .maxHang(_):
                    maxHangView()
                }
            }.navigationTitle("Edit Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .toolbar(content: toolbarContent)
        }.presentationDetents([.large])
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
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
                showing = false
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
        }
    }
    
    func save() {
        switch exercise {
        case .generic(_):
            exercise = .generic(.init(expected: generic, actual: data.map({ $0.toGeneric(generic) }), notes: notes))
        case .repeater(_):
            exercise = .repeater(.init(expected: repeater, actual: data.map({ $0.toRepeater() }), notes: notes))
        case .maxHang(_):
            exercise = .maxHang(.init(expected: maxHang, actual: data.map({ $0.toMaxHang() }), notes: notes))
        }
        showing = false
    }
    
    @ViewBuilder
    func genericView() -> some View {
        switch editType {
        case .Exercise:
            genericBaseView()
        case .Data:
            genericDataView()
        }
    }
    
    @ViewBuilder
    func genericBaseView() -> some View {
        Section {
            TextField("Name", text: $generic.name)
            Picker("Type", selection: $generic.dataType) {
                ForEach(Routine.GenericSets.DataType.allCases, id: \.name) { type in
                    Text(type.name).tag(type)
                }
            }
            Picker("Sided-ness", selection: $generic.sideType) {
                Text("None").tag(nil as Routine.GenericSets.SideType?)
                ForEach(Routine.GenericSets.SideType.allCases, id: \.name) { type in
                    Text(type.name).tag(type as Routine.GenericSets.SideType?)
                }
            }
        }
        Section {
            ForEach($generic.sets.enumerated(), id: \.offset) { offset, $set in
                switch selectionType {
                case .single:
                    Stepper(value: .init(get: {
                        $set.wrappedValue.min
                    }, set: { newValue in
                        $set.wrappedValue.min = newValue
                        $set.wrappedValue.max = newValue
                    }), in: 1...100, step: 1) {
                        Text("\(set.min) \(generic.setDetailText)")
                    }
                case .range:
                    HStack {
                        Stepper(value: $set.min, in: 1...100, step: 1) {
                            Text("\(set.min) \(generic.setDetailText)")
                        }
                        Stepper(value: $set.max, in: 1...100, step: 1) {
                            Text("\(set.max) \(generic.setDetailText)")
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
                        if let last = generic.sets.last {
                            generic.sets.append(.init(min: last.min, max: last.max))
                        } else {
                            generic.sets.append(.init())
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button {
                        generic.sets.removeLast()
                    } label: {
                        Image(systemName: "minus")
                    }.disabled(generic.sets.isEmpty)
                }.buttonStyle(.plain)
                Picker("", selection: $selectionType) {
                    ForEach(SelectionType.allCases, id: \.name) { type in
                        Text(type.name).tag(type)
                    }
                }.pickerStyle(.segmented)
            }
        }
    }
    
    @ViewBuilder
    func genericDataView() -> some View {
        Section {
            ForEach($data.enumerated(), id: \.offset) { offset, $set in
                VStack {
                    if generic.sideType == .independent && multiSide {
                        HStack {
                            VStack(alignment: .leading, spacing: 16) {
                                Stepper("\(set.numLeft) \(generic.setDetailText)", value: $set.numLeft, in: 0...30, step: 1)
                                switch generic.dataType {
                                case .repWeight, .timeWeight:
                                    Stepper(set.weightLeft.lbsFormat, value: $set.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0...2)))
                                case .rep, .time:
                                    EmptyView()
                                }
                            }
                            VStack(alignment: .trailing, spacing: 16) {
                                Stepper("\(set.numRight) \(generic.setDetailText)", value: $set.numRight, in: 0...30, step: 1)
                                switch generic.dataType {
                                case .repWeight, .timeWeight:
                                    Stepper(set.weightRight.lbsFormat, value: $set.weightRight, in: -200...200, step: 5, format: .number.precision(.fractionLength(0...2)))
                                case .rep, .time:
                                    EmptyView()
                                }
                            }
                        }
                    } else {
                        HStack {
                            Stepper("\(set.numLeft) \(generic.setDetailText)", value: $set.numLeft, in: 0...30, step: 1)
                            switch generic.dataType {
                            case .repWeight, .timeWeight:
                                Stepper(set.weightLeft.lbsFormat, value: $set.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0...2)))
                            case .rep, .time:
                                EmptyView()
                            }
                        }
                    }
                    TextField("Notes", text: $set.notes, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
        } header: {
            VStack(alignment: .leading) {
                if generic.sideType == .independent {
                    Toggle("Different Side Values", isOn: $multiSide)
                }
                HStack {
                    Text("Sets")
                    Spacer()
                    Button("Add") {
                        let expected = generic.sets[data.count]
                        data.append(.init(numLeft: expected.avg, weightLeft: data.last?.weightLeft))
                    }.disabled(data.count >= generic.sets.count)
                    Button("Remove") {
                        data.removeLast()
                    }.disabled(data.isEmpty)
                }
            }
        }
        Section("Notes") {
            TextField("optional", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    @ViewBuilder
    func repeaterView() -> some View {
        switch editType {
        case .Exercise:
            repeaterBaseView()
        case .Data:
            repeaterDataView()
        }
    }
    
    @ViewBuilder
    func repeaterBaseView() -> some View {
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
                    if data.count > repeater.sets.count {
                        data.removeLast()
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
            ForEach($data.enumerated(), id: \.offset) { offset, $set in
                VStack {
                    HStack {
                        Stepper("\(set.numLeft) reps", value: $set.numLeft, in: 0...30, step: 1)
                        Stepper(set.weightLeft.lbsFormat, value: $set.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0...2)))
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
                    let expected = repeater.sets[data.count]
                    data.append(.init(numLeft: expected.numReps, weightLeft: expected.weight))
                }.disabled(data.count >= repeater.sets.count)
                Button("Remove") {
                    data.removeLast()
                }.disabled(data.isEmpty)
            }
        }
        Section("Notes") {
            TextField("optional", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    @ViewBuilder
    func maxHangView() -> some View {
        switch editType {
        case .Exercise:
            maxHangBaseView()
        case .Data:
            maxHangDataView()
        }
    }
    
    @ViewBuilder
    func maxHangBaseView() -> some View {
        Section {
            TextField("Tag", text: $maxHang.tag)
        }
        Section {
            ForEach($maxHang.sets.filter({ $0.wrappedValue.side == .left }).enumerated(), id: \.offset) { offset, $set in
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
        } header: {
            HStack(spacing: 16) {
                Text("Left")
                Spacer()
                Button {
                    if let left = maxHang.sets.filter({ $0.side == .left }).last {
                        maxHang.sets.append(.init(side: .left, target: left.target, weight: left.weight))
                    } else {
                        maxHang.sets.append(.init(side: .left))
                    }
                    if let right = maxHang.sets.filter({ $0.side == .right }).last {
                        maxHang.sets.append(.init(side: .right, target: right.target, weight: right.weight))
                    } else {
                        maxHang.sets.append(.init(side: .right))
                    }
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    maxHang.sets.removeLast(2)
                } label: {
                    Image(systemName: "minus")
                }.disabled(maxHang.sets.isEmpty)
            }.buttonStyle(.plain)
        }
        Section("Right") {
            ForEach($maxHang.sets.filter({ $0.wrappedValue.side == .right }).enumerated(), id: \.offset) { offset, $set in
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
    }
    
    @ViewBuilder
    func maxHangDataView() -> some View {
        Section {
            ForEach($data.enumerated(), id: \.offset) { offset, $set in
                VStack {
                    HStack {
                        Stepper("\(set.side.abbreviation) \(set.numLeft)s", value: $set.numLeft, in: 0...30, step: 1)
                        Stepper(set.weightLeft.lbsFormat, value: $set.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0...2)))
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
                    let left = maxHang.sets[data.count]
                    data.append(.init(side: left.side, numLeft: left.target, weightLeft: left.weight))
                    let right = maxHang.sets[data.count]
                    data.append(.init(side: right.side, numLeft: right.target, weightLeft: right.weight))
                }.disabled(data.count >= maxHang.sets.count)
                Button("Remove") {
                    data.removeLast()
                    data.removeLast()
                }.disabled(data.isEmpty)
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

#Preview("Generic") {
    @Previewable @State var exercise: Session.Exercise = .generic(.init(expected: .init(name: "Barbell Bench Press", dataType: .repWeight, sideType: .independent, sets: [
        .init(num: 10),
        .init(num: 8),
        .init(num: 6),
        .init(min: 3, max: 5),
    ]), actual: [
        .init(numReps: 10, weight: 80),
        .init(numReps: 8, weight: 90),
        .init(numReps: 6, weight: 100, notes: "Test"),
        .init(numReps: 4, weight: 120, notes: "Test again"),
    ], notes: "Light work baybeeee"))
    @Previewable @State var showSheet = false
    Form {
        Button {
            showSheet = true
        } label: {
            SessionExerciseEntryView(exercise: exercise)
        }.buttonStyle(.plain)
    }.sheet(isPresented: $showSheet) {
        SessionExerciseSheet(exercise: $exercise, showing: $showSheet)
    }
}

#Preview("Repeater") {
    @Previewable @State var exercise: Session.Exercise = .repeater(.init(expected: .init(tag: "HC 15mm", sets: [
        .init(numReps: 7),
        .init(numReps: 6, weight: 10),
        .init(numReps: 5, weight: 20)
    ]), actual: [
        .init(numReps: 6, notes: "Tricky"),
        .init(numReps: 5, weight: 5),
        .init(numReps: 4, weight: 10)
    ], notes: "Test notes for these repeaters"))
    @Previewable @State var showSheet = false
    Form {
        Button {
            showSheet = true
        } label: {
            SessionExerciseEntryView(exercise: exercise)
        }.buttonStyle(.plain)
    }.sheet(isPresented: $showSheet) {
        SessionExerciseSheet(exercise: $exercise, showing: $showSheet)
    }
}

#Preview("Max Hang") {
    @Previewable @State var exercise: Session.Exercise = .maxHang(.init(expected: .init(tag: "BM Middle", sets: [
        .init(side: .left, target: 10, weight: 35),
        .init(side: .right, target: 10, weight: 40),
        .init(side: .left, target: 8, weight: 40),
        .init(side: .right, target: 8, weight: 45),
    ]), actual: [
        .init(side: .left, target: 10, weight: 35),
        .init(side: .right, target: 9, weight: 40, notes: "Too much"),
        .init(side: .left, target: 6, weight: 40),
        .init(side: .right, target: 5, weight: 50, notes: "EZ"),
    ], notes: "Why am i doing this"))
    @Previewable @State var showSheet = false
    Form {
        Button {
            showSheet = true
        } label: {
            SessionExerciseEntryView(exercise: exercise)
        }.buttonStyle(.plain)
    }.sheet(isPresented: $showSheet) {
        SessionExerciseSheet(exercise: $exercise, showing: $showSheet)
    }
}
