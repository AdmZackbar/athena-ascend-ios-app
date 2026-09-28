//
//  RoutineDataEditSheet.swift
//  Athena
//
//  Created by Zach Wassynger on 9/26/26.
//

import SwiftData
import SwiftUI

extension ExerciseData.Value {
    var editType: RoutineDataEditSheet.FieldEditType {
        switch self {
        case .number(_), .discrete(_): return .value
        case .range(_, _): return .range
        case .text(_): return .text
        case .campus(_): return .campus
        }
    }
}

struct RoutineDataEditSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let data: RoutineData
    
    var canMirror: Bool {
        switch data.exercise.category {
        case .generic(_, _, let sideType): return sideType == .independent
        case .repeater(_, _, _): return false
        case .maxHang(_, let sideType): return sideType == .independent
        case .campus(_, let mirrorSets): return mirrorSets
        }
    }
    
    var invalid: Bool {
        if sets.isEmpty {
            return false
        }
        return sets.allSatisfy { $0.0.isEmpty || $0.1.isEmpty }
    }
    
    @State private var sets: [(ExerciseData.DataSet, [ExerciseData.Field: FieldEditType])]
    @State private var showAlt: Bool
    @State private var discreteStep: Int = 1
    @State private var numberStep: Double = 5
    @State private var editSetIndex: Int = 0
    @State private var setEditType: EditType
    
    enum EditType: CaseIterable {
        case simple, perSet
        
        var text: String {
            switch self {
            case .simple: "Simple"
            case .perSet: "Per-Set"
            }
        }
    }
    
    enum FieldEditType: CaseIterable {
        case value, range, text, campus
        
        var text: String {
            switch self {
            case .value: "Value"
            case .range: "Range"
            case .text: "Custom"
            case .campus: "Moves"
            }
        }
    }
    
    init(data: RoutineData) {
        self.data = data
        self.showAlt = data.expectedData.contains(where: { $0.hasAlt })
        self.setEditType = {
            if data.expectedData.isEmpty {
                return .simple
            }
            return data.expectedData.dropFirst().allSatisfy { $0 == data.expectedData.first } ? .simple : .perSet
        }()
        self.sets = data.expectedData.map { entry in
            var dict: [ExerciseData.Field: FieldEditType] = .init()
            let dataTypes: [Exercise.DataType] = {
                switch data.exercise.category {
                case .generic(_, let dataTypes, _):
                    return dataTypes
                case .repeater(_, _, _):
                    return [.reps, .weight]
                case .maxHang(_, _):
                    return [.time, .weight]
                case .campus(_, _):
                    return []
                }
            }()
            // Only need main field, don't care about alt
            dataTypes.map { ($0.field, entry[$0.field]?.editType) }.forEach { dict[$0.0] = $0.1 }
            // Have to handle campus directly (no link in data types)
            if let editType = entry[.campus]?.editType {
                dict[.campus] = editType
            }
            return (entry, dict)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("\(sets.count) Sets", value: .init(get: {
                        sets.count
                    }, set: { newValue in
                        if newValue < sets.count {
                            // Remove trailing data sets
                            sets.removeLast(sets.count - newValue)
                        } else {
                            // Add data sets based on last one
                            for _ in sets.count..<newValue {
                                sets.append(sets.last ?? (.init(), .init()))
                            }
                        }
                    }), in: 0...99)
                    if setEditType == .perSet {
                        Picker("Edit Set", selection: $editSetIndex) {
                            ForEach(0..<sets.count, id: \.self) { setIndex in
                                Text("Set \(setIndex + 1)").tag(setIndex)
                            }
                        }
                    }
                }
                summaryView()
                if !sets.isEmpty {
                    setEditors()
                }
            }.navigationTitle(setEditType.text)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: toolbarContent)
                .onChange(of: setEditType) { _, newValue in
                    // Reset edit index each time
                    editSetIndex = 0
                    // Overwrite custom data when switching to simple
                    if newValue == .simple, let template = sets.first {
                        for index in sets.indices {
                            sets[index] = template
                        }
                    }
                }
        }.presentationDetents([.large])
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarTitleMenu {
            Picker("Set Type", selection: $setEditType) {
                ForEach(EditType.allCases, id: \.text) { t in
                    Text(t.text).tag(t)
                }
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Menu("Unit Step Size") {
                    ForEach([1, 5, 10], id: \.self) { step in
                        Button("\(step.formatted()) units") {
                            discreteStep = Int(step)
                        }.disabled(discreteStep == step)
                    }
                }
                Menu("Weight Step Size") {
                    ForEach([1, 2.5, 5, 10], id: \.self) { step in
                        Button("\(step.formatted(.number.precision(.fractionLength(0...1)))) lbs") {
                            numberStep = step
                        }.disabled(numberStep == step)
                    }
                }
            } label: {
                Label("Options", systemImage: "gear")
            }
            if canMirror {
                Button {
                    showAlt.toggle()
                } label: {
                    Image(systemName: showAlt ? "square.lefthalf.filled" : "square")
                }
            }
            Button {
                data.expectedData = sets.map { (dataSet, _) in
                    if canMirror && !showAlt {
                        // Strip out all alt values
                        return dataSet.filter { !$0.key.isAlt }
                    } else if showAlt {
                        // Remove all dupe alt values
                        return dataSet.dedupe()
                    }
                    return dataSet
                }
                dismiss()
            } label: {
                Label("Save", systemImage: "checkmark")
            }.disabled(invalid)
        }
    }
    
    @ViewBuilder
    func summaryView() -> some View {
        Section("Summary") {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.exercise.name)
                    .italic()
                if sets.isEmpty {
                    Text("No Sets")
                        .italic()
                } else {
                    Grid(alignment: .leading) {
                        ForEach(sets.enumerated(), id: \.offset) { offset, set in
                            GridRow(alignment: .top) {
                                Text("Set \(offset + 1)")
                                    .fontWeight(.semibold)
                                ExpectedDataSetView(exercise: data.exercise, dataSet: set.0)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func setEditors() -> some View {
        switch data.exercise.category {
        case .generic(_, let dataTypes, _):
            // Force consistent order
            ForEach(Exercise.DataType.allCases.enumerated(), id: \.offset) { offset, dataType in
                if dataTypes.contains(dataType) {
                    editorGroup(dataType: dataType)
                }
            }
        case .repeater(_, _, _):
            editorGroup(dataType: .reps)
            editorGroup(dataType: .weight)
        case .maxHang(_, _):
            editorGroup(dataType: .time)
            editorGroup(dataType: .weight)
        case .campus(_, _):
            campusEditorGroup()
        }
    }
    
    @ViewBuilder
    func editorGroup(dataType: Exercise.DataType) -> some View {
        Section {
            if showAlt {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    fieldEditor(dataType: dataType)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    fieldEditor(dataType: dataType, alt: true)
                }
            } else if canMirror {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Both")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    fieldEditor(dataType: dataType)
                }
            } else {
                fieldEditor(dataType: dataType)
            }
        } header: {
            HStack {
                Text(fieldName(dataType))
                Spacer()
                Picker("Type", selection: .init(get: {
                    sets[editSetIndex].1[dataType.field]
                }, set: { newValue in
                    sets[editSetIndex].1[dataType.field] = newValue
                    // Special cases: need to reset data
                    switch newValue {
                    case .text, .none:
                        sets[editSetIndex].0.removeValue(forKey: dataType.field)
                        sets[editSetIndex].0.removeValue(forKey: dataType.altField)
                    default:
                        break
                    }
                })) {
                    Text("None").tag(nil as FieldEditType?)
                    ForEach(FieldEditType.allCases.dropLast(), id: \.text) { t in
                        Text(t.text).tag(t as FieldEditType?)
                    }
                }.pickerStyle(.segmented)
                    .frame(width: 260)
            }
        }
    }
    
    @ViewBuilder
    func fieldEditor(dataType: Exercise.DataType, alt: Bool = false) -> some View {
        let field = dataType.getField(alt: alt)
        // Need to check based on field, not altField
        switch sets[editSetIndex].1[dataType.field] {
        case .value:
            stepper(dataType: dataType, alt: alt)
        case .range:
            VStack(alignment: .leading) {
                Text(sets[editSetIndex].0.getText(dataType, useAlt: alt) ?? "N/A")
                HStack(spacing: 8) {
                    Stepper("Min", value: .init(get: {
                        getMin(field: field) ?? getInt(field: field) ?? 0
                    }, set: { newValue in
                        let max = getMax(field: field) ?? newValue
                        let value: ExerciseData.Value = newValue >= max ? .discrete(newValue) : .range(min: newValue, max: max)
                        setValue(dataType: dataType, alt: alt, value: value)
                    }))
                    Stepper("Max", value: .init(get: {
                        getMax(field: field) ?? getInt(field: field) ?? 0
                    }, set: { newValue in
                        let min = getMin(field: field) ?? newValue
                        let value: ExerciseData.Value = newValue <= min ? .discrete(newValue) : .range(min: min, max: newValue)
                        setValue(dataType: dataType, alt: alt, value: value)
                    }))
                }
            }
        case .text:
            TextField("Custom", text: .init(get: {
                getString(field: field)
            }, set: { newValue in
                if !newValue.isEmpty {
                    sets[editSetIndex].0[field] = .text(newValue)
                } else {
                    sets[editSetIndex].0.removeValue(forKey: field)
                }
            }))
        case .campus, .none:
            EmptyView()
        }
    }
    
    @ViewBuilder
    func stepper(dataType: Exercise.DataType, alt: Bool = false) -> some View {
        switch dataType {
        case .reps, .time, .distance:
            Stepper(sets[editSetIndex].0.getText(dataType, useAlt: alt) ?? "0\(dataType.getUnit(0))", value: .init(get: {
                if alt, let altValue = getInt(field: dataType.altField) {
                    return altValue
                }
                return getInt(field: dataType.field) ?? 0
            }, set: { newValue in
                setValue(dataType: dataType, alt: alt, value: .discrete(newValue))
            }), in: 0...999, step: discreteStep)
        case .weight:
            Stepper(sets[editSetIndex].0.getText(dataType, useAlt: alt) ?? "0 lbs", value: .init(get: {
                if alt, let altValue = getDouble(field: dataType.altField) {
                    return altValue
                }
                return getDouble(field: dataType.field) ?? 0
            }, set: { newValue in
                setValue(dataType: dataType, alt: alt, value: .number(newValue))
            }), in: 0...999, step: numberStep, format: .number.precision(.fractionLength(0...1)))
        }
    }
    
    @ViewBuilder
    func campusEditorGroup() -> some View {
        Section {
            campusEditor()
            if showAlt {
                campusEditor(alt: true)
            }
        } header: {
            HStack {
                Text("Campus")
                Spacer()
                Picker("Type", selection: .init(get: {
                    sets[editSetIndex].1[.campus]
                }, set: { newValue in
                    sets[editSetIndex].1[.campus] = newValue
                    // Special cases: need to reset data
                    switch newValue {
                    case .text, .none:
                        sets[editSetIndex].0.removeValue(forKey: .campus)
                        sets[editSetIndex].0.removeValue(forKey: .campusAlt)
                    default:
                        break
                    }
                })) {
                    ForEach([FieldEditType.campus, FieldEditType.text], id: \.text) { t in
                        Text(t.text).tag(t as FieldEditType?)
                    }
                }.pickerStyle(.segmented)
                    .frame(width: 200)
            }
        }
    }
    
    @ViewBuilder
    func campusEditor(alt: Bool = false) -> some View {
        switch sets[editSetIndex].1[.campus] {
        case .campus:
            let current: CampusSet = {
                if alt {
                    return getCampusSet(field: .campusAlt) ?? getCampusSet(field: .campus)?.flipped() ?? .init(board: .largeEdges, moves: [])
                } else {
                    return getCampusSet(field: .campus) ?? .init(board: .largeEdges, moves: [])
                }
            }()
            NavigationLink {
                CampusBoardView(set: current) { newSet in
                    sets[editSetIndex].0[alt ? .campusAlt : .campus] = .campus(newSet)
                }
            } label: {
                Text(current.moves.text)
            }
        case .text:
            let field: ExerciseData.Field = alt ? .campusAlt : .campus
            TextField("Custom", text: .init(get: {
                getString(field: field)
            }, set: { newValue in
                if !newValue.isEmpty {
                    sets[editSetIndex].0[field] = .text(newValue)
                } else {
                    sets[editSetIndex].0.removeValue(forKey: field)
                }
            }))
        default:
            EmptyView()
        }
    }
    
    private func getInt(field: ExerciseData.Field) -> Int? {
        switch sets[editSetIndex].0[field] {
        case .discrete(let v): return v
        // Fallback methods
        case .number(let v): return Int(v)
        case .range(let min, let max): return min + ((max - min) / 2)
        default: return nil
        }
    }
    
    private func getDouble(field: ExerciseData.Field) -> Double? {
        switch sets[editSetIndex].0[field] {
        case .number(let v): return v
        // Fallback methods
        case .discrete(let v): return Double(v)
        case .range(let min, let max): return Double(min) + (Double((max - min)) / 2)
        default: return nil
        }
    }
    
    private func getString(field: ExerciseData.Field) -> String {
        switch sets[editSetIndex].0[field] {
        case .text(let str): return str
        default: return ""
        }
    }
    
    private func getMin(field: ExerciseData.Field) -> Int? {
        switch sets[editSetIndex].0[field] {
        case .range(let min, _): return min
        // Fallback methods
        case .number(let v): return Int(v)
        case .discrete(let v): return v
        default: return nil
        }
    }
    
    private func getMax(field: ExerciseData.Field) -> Int? {
        switch sets[editSetIndex].0[field] {
        case .range(_, let max): return max
        // Fallback methods
        case .number(let v): return Int(v)
        case .discrete(let v): return v
        default: return nil
        }
    }
    
    private func getCampusSet(field: ExerciseData.Field) -> CampusSet? {
        switch sets[editSetIndex].0[field] {
        case .campus(let set): return set
        default: return nil
        }
    }
    
    private func setValue(dataType: Exercise.DataType, alt: Bool, value: ExerciseData.Value) {
        sets[editSetIndex].0[alt ? dataType.altField : dataType.field] = value
    }
    
    private func fieldName(_ dataType: Exercise.DataType) -> String {
        switch dataType {
        case .reps: "Reps"
        case .time: "Time"
        case .weight: "Weight"
        case .distance: "Height"
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineEditView(routine: routines.first!)
    }
}
