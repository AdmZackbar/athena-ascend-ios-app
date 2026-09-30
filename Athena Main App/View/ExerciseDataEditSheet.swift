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
        exercise.canMirror
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
                        DataSetEditor(exercise: exercise, dataSet: .init(get: {
                            athleteData[selectedAthlete, default: []][setIndex]
                        }, set: { newValue in
                            athleteData[selectedAthlete, default: [.init()]][setIndex] = newValue
                        }), sides: showAlt ? .split : (canMirror ? .both : .single), discreteStep: discreteStep, numberStep: numberStep)
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
                    // An athlete can reach this sheet (via the picker) without an existing
                    // row for this position - e.g. one added to the session after this
                    // exercise slot was created. Create it instead of assuming it exists.
                    let exerciseData: ExerciseData
                    if let existing = session.data.first(where: { $0.athlete == athlete && $0.position == position }) {
                        exerciseData = existing
                    } else {
                        exerciseData = ExerciseData(exercise: exercise, session: session, athlete: athlete, position: position)
                        session.data.append(exerciseData)
                    }
                    exerciseData.actualData = athleteData[athlete, default: []].map { dataSet in
                        dataSet.normalized(canMirror: canMirror, showAlt: showAlt)
                    }
                    exerciseData.notes = athleteNotes[athlete, default: ""]
                }
                dismiss()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var sessions: [Session]
    ExerciseDataEditSheet(session: sessions.filter({ !$0.data.isEmpty }).first!, position: .init(superSetIndex: 0, setIndex: 4))
}
