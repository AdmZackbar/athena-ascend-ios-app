//
//  ExerciseDataEditSheet.swift
//  Athena
//
//  Created by Zach Wassynger on 9/26/26.
//

import SwiftData
import SwiftUI

/// Used to add, edit, and remove data sets from an `ExerciseData` entry.
struct ExerciseDataEditSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let session: Session
    let position: ExerciseData.Position
    let exercise: Exercise
    
    var canMirror: Bool {
        switch exercise.category {
        case .generic(_, _, let sideType): return sideType == .independent
        case .repeater(_, _, _): return false
        case .maxHang(_, let sideType): return sideType == .independent
        case .campus(_, let mirrorSets): return mirrorSets
        }
    }
    
    @State private var athleteData: [Athlete: [ExerciseData.DataSet]]
    @State private var athleteNotes: [Athlete: String]
    @State private var selectedAthlete: Athlete
    @State private var showAlt: Bool
    @State private var discreteStep: Int = 1
    @State private var numberStep: Double = 5
    
    init(session: Session, position: ExerciseData.Position, initialAthlete: Athlete? = nil) {
        self.session = session
        self.position = position
        let exerciseData = session.data.filter({ $0.position == position })
        self.exercise = exerciseData.first!.exercise
        let athleteDataMap: [Athlete: [ExerciseData]] = .init(grouping: exerciseData, by: { $0.athlete })
        self.athleteData = athleteDataMap.mapValues { $0.first?.actualData ?? [] }
        self.athleteNotes = athleteDataMap.mapValues { $0.first?.notes ?? "" }
        let athlete = initialAthlete ?? session.athletes.sorted(by: { $0.name < $1.name }).first!
        self.selectedAthlete = athlete
        self.showAlt = athleteDataMap[athlete, default: []].contains(where: { $0.actualData.hasAlt })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if session.athletes.count > 1 {
                    Picker("Athlete", selection: $selectedAthlete) {
                        ForEach(session.athletes.sorted(by: { $0.name < $1.name }), id: \.uuid) { athlete in
                            Text(athlete.name).tag(athlete)
                        }
                    }
                }
                Section("Exercise Notes") {
                    TextField("Optional", text: .init(get: {
                        athleteNotes[selectedAthlete] ?? ""
                    }, set: { newValue in
                        athleteNotes[selectedAthlete] = newValue.isEmpty ? nil : newValue
                    }), axis: .vertical)
                    .lineLimit(1...3)
                }
                let numSets = athleteData[selectedAthlete, default: []].count
                ForEach(0..<numSets, id: \.self) { setIndex in
                    Section {
                        editor(setIndex: setIndex)
                        TextField("Notes", text: .init(get: {
                            getString(setIndex, field: .notes)
                        }, set: { newValue in
                            if newValue.isEmpty {
                                athleteData[selectedAthlete, default: [.init()]][setIndex].removeValue(forKey: .notes)
                            } else {
                                athleteData[selectedAthlete, default: [.init()]][setIndex][.notes] = .text(newValue)
                            }
                        })).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        HStack {
                            Text("Set \(setIndex + 1)")
                                .bold()
                            Spacer()
                            Button(role: .destructive) {
                                athleteData[selectedAthlete]!.remove(at: setIndex)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                Button {
                    let setIndex = athleteData[selectedAthlete]?.count ?? 0
                    var initialData: ExerciseData.DataSet = .init()
                    if let latest = athleteData[selectedAthlete]?.last {
                        // Try to use the latest set as a base
                        initialData = latest
                    }
                    if let expected = session.data.filter({ $0.position == position }).first?.expectedData, expected.count > setIndex {
                        // If we have expected data, prioritize those values
                        initialData.override(expected[setIndex].expectedToActual())
                    }
                    athleteData[selectedAthlete, default: []].append(initialData)
                } label: {
                    Label("Add Set", systemImage: "plus")
                }
            }.navigationTitle(exercise.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: toolbarContent)
                .onChange(of: selectedAthlete) { oldValue, newValue in
                    showAlt = athleteData[newValue, default: []].contains(where: { $0.hasAlt })
                }
        }.presentationDetents([.large])
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
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
                session.athletes.forEach { athlete in
                    let exerciseData = session.data.filter { $0.athlete == athlete && $0.position == position }.first!
                    exerciseData.actualData = athleteData[athlete, default: []].map { dataSet in
                        if canMirror && !showAlt {
                            // Strip out all alt values
                            return dataSet.filter { !$0.key.isAlt }
                        } else if showAlt {
                            // Remove all dupe alt values
                            return dataSet.dedupe()
                        }
                        return dataSet
                    }
                    exerciseData.notes = athleteNotes[athlete, default: ""]
                }
                dismiss()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
        }
    }
    
    @ViewBuilder
    func editor(setIndex: Int) -> some View {
        switch exercise.category {
        case .generic(_, let dataTypes, _):
            // Force consistent order
            ForEach(Exercise.DataType.allCases.enumerated(), id: \.offset) { offset, dataType in
                if dataTypes.contains(dataType) {
                    stepperGroup(setIndex, dataType: dataType)
                }
            }
        case .repeater(_, _, _):
            stepperGroup(setIndex, dataType: .reps)
            stepperGroup(setIndex, dataType: .weight)
        case .maxHang(_, _):
            stepperGroup(setIndex, dataType: .time)
            stepperGroup(setIndex, dataType: .weight)
        case .campus(_, _):
            campusEditor(setIndex)
            if showAlt {
                campusEditor(setIndex, alt: true)
            }
        }
    }
    
    @ViewBuilder
    func stepperGroup(_ setIndex: Int, dataType: Exercise.DataType) -> some View {
        if showAlt {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    stepper(setIndex, dataType: dataType)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    stepper(setIndex, dataType: dataType, alt: true)
                }
            }
        } else if canMirror {
            VStack(alignment: .leading, spacing: 2) {
                Text("Both")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                stepper(setIndex, dataType: dataType)
            }
        } else {
            stepper(setIndex, dataType: dataType)
        }
    }
    
    @ViewBuilder
    func stepper(_ setIndex: Int, dataType: Exercise.DataType, alt: Bool = false) -> some View {
        switch dataType {
        case .reps, .time, .distance:
            Stepper(athleteData[selectedAthlete]?[setIndex].getText(dataType, useAlt: alt) ?? "0\(dataType.getUnit(0))", value: .init(get: {
                if alt, let altValue = getInt(setIndex, field: dataType.altField) {
                    return altValue
                }
                return getInt(setIndex, field: dataType.field) ?? 0
            }, set: { newValue in
                setValue(setIndex, dataType: dataType, alt: alt, value: .discrete(newValue))
            }), in: 0...999, step: discreteStep)
        case .weight:
            Stepper(athleteData[selectedAthlete]?[setIndex].getText(dataType, useAlt: alt) ?? "0 lbs", value: .init(get: {
                if alt, let altValue = getDouble(setIndex, field: dataType.altField) {
                    return altValue
                }
                return getDouble(setIndex, field: dataType.field) ?? 0
            }, set: { newValue in
                setValue(setIndex, dataType: dataType, alt: alt, value: .number(newValue))
            }), in: 0...999, step: numberStep, format: .number.precision(.fractionLength(0...1)))
        }
    }
    
    @ViewBuilder
    func campusEditor(_ setIndex: Int, alt: Bool = false) -> some View {
        let current: CampusSet = {
            if alt {
                return getCampusSet(setIndex, field: .campusAlt) ?? getCampusSet(setIndex, field: .campus)?.flipped() ?? .init(board: .largeEdges, moves: [])
            } else {
                return getCampusSet(setIndex, field: .campus) ?? .init(board: .largeEdges, moves: [])
            }
        }()
        NavigationLink {
            CampusBoardView(set: current) { newSet in
                athleteData[selectedAthlete]?[setIndex][alt ? .campusAlt : .campus] = .campus(newSet)
            }
        } label: {
            Text(current.moves.text)
        }
    }
    
    private func getInt(_ setIndex: Int, field: ExerciseData.Field) -> Int? {
        switch athleteData[selectedAthlete]?[setIndex][field] {
        case .discrete(let v): return v
        default: return nil
        }
    }
    
    private func getDouble(_ setIndex: Int, field: ExerciseData.Field) -> Double? {
        switch athleteData[selectedAthlete]?[setIndex][field] {
        case .number(let v): return v
        default: return nil
        }
    }
    
    private func getString(_ setIndex: Int, field: ExerciseData.Field) -> String {
        switch athleteData[selectedAthlete]?[setIndex][field] {
        case .text(let str): return str
        default: return ""
        }
    }
    
    private func getCampusSet(_ setIndex: Int, field: ExerciseData.Field) -> CampusSet? {
        switch athleteData[selectedAthlete]?[setIndex][field] {
        case .campus(let set): return set
        default: return nil
        }
    }
    
    private func setValue(_ setIndex: Int, dataType: Exercise.DataType, alt: Bool, value: ExerciseData.Value) {
        athleteData[selectedAthlete, default: [.init()]][setIndex][dataType.getField(alt: alt)] = value
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var sessions: [Session]
    ExerciseDataEditSheet(session: sessions.filter({ !$0.data.isEmpty }).first!, position: .init(superSetIndex: 0, setIndex: 4))
}
