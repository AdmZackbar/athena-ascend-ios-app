//
//  TeamSessionView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import SwiftData
import SwiftUI

/// Data-entry surface for a team session: several athletes performing the same
/// exercises, with a result recorded for each. Deliberately not the guided,
/// timer-driven "exercise view" `RoutineSessionView` uses for a single athlete — there
/// is no one person to time here, just numbers to enter and review.
struct TeamSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var teamSession: TeamSession

    @State private var sheetType: SheetType? = nil
    @State private var newAthleteName: String = ""
    @State private var removeEntry: Session? = nil
    @State private var deleteExercise: (setIndex: Int, exerciseIndex: Int)? = nil
    @State private var showDeleteAlert: Bool = false

    private enum SheetType: Identifiable {
        case date
        case athletePicker
        case newAthlete
        case exercisePicker(setIndex: Int)
        case exerciseBase(setIndex: Int, exerciseIndex: Int)

        var id: String {
            switch self {
            case .date: return "date"
            case .athletePicker: return "athletePicker"
            case .newAthlete: return "newAthlete"
            case .exercisePicker(let setIndex): return "exercisePicker-\(setIndex)"
            case .exerciseBase(let setIndex, let exerciseIndex): return "exerciseBase-\(setIndex)-\(exerciseIndex)"
            }
        }
    }

    var title: String {
        teamSession.routine?.name ?? teamSession.routineName ?? teamSession.startTime.formatted(date: .numeric, time: .shortened)
    }

    var finished: Bool {
        teamSession.endTime != nil
    }

    private var totalExerciseCount: Int {
        teamSession.sets.flatMap(\.exercises).count
    }

    private func recordedCount(for entry: Session) -> Int {
        entry.sets.flatMap(\.exercises).filter(\.hasData).count
    }

    var body: some View {
        Form {
            headerSection()
            athletesSection()
            exerciseSections()
        }.navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar(content: buildToolbar)
            .sheet(item: $sheetType, content: sheetContent)
            .alert("Remove Athlete?", isPresented: .init(get: {
                removeEntry != nil
            }, set: { newValue in
                if !newValue {
                    removeEntry = nil
                }
            })) {
                Button("Remove", role: .destructive) {
                    if let removeEntry {
                        teamSession.removeEntry(removeEntry, context: modelContext)
                    }
                    removeEntry = nil
                }
            } message: {
                Text("This removes \(removeEntry?.athleteDisplayName ?? "this athlete")'s recorded data for this session. This can't be undone.")
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
                        teamSession.removeExercise(at: deleteExercise.exerciseIndex, inSet: deleteExercise.setIndex)
                    }
                    deleteExercise = nil
                }
            }
            .alert("Delete this team session?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(teamSession)
                    dismiss()
                }
            } message: {
                Text("This deletes every athlete's recorded data for this session. This can't be undone.")
            }
    }

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                if !finished {
                    Button {
                        teamSession.finish(context: modelContext)
                    } label: {
                        Label("Finish Session", systemImage: "checkmark")
                    }
                } else {
                    Button {
                        sheetType = .date
                    } label: {
                        Label("Edit Start/End Date", systemImage: "calendar")
                    }
                    Button {
                        teamSession.reopen()
                    } label: {
                        Label("Re-open Session", systemImage: "play")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
        }
    }

    @ViewBuilder
    private func headerSection() -> some View {
        Section {
            if finished, let endTime = teamSession.endTime {
                HStack {
                    Text(teamSession.startTime.formatted(date: .numeric, time: .shortened))
                    Spacer()
                    Text(Duration.seconds(endTime.timeIntervalSince(teamSession.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                }
            } else {
                DatePicker("Start:", selection: $teamSession.startTime, displayedComponents: [.date, .hourAndMinute])
            }
            TextField("Notes", text: $teamSession.notes, axis: .vertical)
                .lineLimit((teamSession.sets.isEmpty ? 9 : 3)...12)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
        } header: {
            if let routine = teamSession.routine {
                Text(routine.name)
            } else if let routineName = teamSession.routineName {
                Text(routineName)
            }
        }
    }

    @ViewBuilder
    private func athletesSection() -> some View {
        Section {
            if teamSession.sortedEntries.isEmpty {
                Text("No athletes yet")
                    .foregroundStyle(.secondary)
            }
            ForEach(teamSession.sortedEntries) { entry in
                NavigationLink {
                    TeamAthleteDetailView(entry: entry)
                } label: {
                    HStack {
                        Text(entry.athleteDisplayName)
                            .fontWeight(.semibold)
                        Spacer()
                        if totalExerciseCount > 0 {
                            Text("\(recordedCount(for: entry))/\(totalExerciseCount) recorded")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }.swipeActions {
                    Button("Remove", systemImage: "trash") {
                        removeEntry = entry
                    }.tint(.red)
                }
            }
        } header: {
            HStack {
                Text("Athletes")
                Spacer()
                if !finished {
                    Menu {
                        Button("From Roster...") {
                            sheetType = .athletePicker
                        }
                        Button("New Athlete...") {
                            newAthleteName = ""
                            sheetType = .newAthlete
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseSections() -> some View {
        ForEach(teamSession.sets.indices, id: \.self) { setIndex in
            Section {
                ForEach(teamSession.sets[setIndex].exercises.indices, id: \.self) { exerciseIndex in
                    NavigationLink {
                        TeamExerciseDetailView(teamSession: teamSession, setIndex: setIndex, exerciseIndex: exerciseIndex)
                    } label: {
                        SessionExerciseEntryView(exercise: teamSession.sets[setIndex].exercises[exerciseIndex])
                    }.swipeActions {
                        if !finished {
                            Button("Delete", systemImage: "trash") {
                                deleteExercise = (setIndex, exerciseIndex)
                            }.tint(.red)
                        }
                    }
                }
            } header: {
                HStack {
                    if finished {
                        Text(teamSession.sets[setIndex].name)
                    } else {
                        TextField("Set Name", text: $teamSession.sets[setIndex].name)
                    }
                    Spacer()
                    if !finished {
                        ExerciseSetHeaderMenu(
                            onPickFromLibrary: { sheetType = .exercisePicker(setIndex: setIndex) },
                            onAddNew: { addNewExercise($0, toSet: setIndex) },
                            onDeleteSet: { teamSession.removeSet(at: setIndex) }
                        )
                    }
                }
            }
        }
        if !finished {
            Button {
                teamSession.addSet(.init(base: .init()))
            } label: {
                Label("Add New Set", systemImage: "plus")
            }
        }
    }

    private func addNewExercise(_ exercise: Session.Exercise, toSet setIndex: Int) {
        teamSession.addExercise(exercise, toSet: setIndex)
        sheetType = .exerciseBase(setIndex: setIndex, exerciseIndex: teamSession.sets[setIndex].exercises.count - 1)
    }

    @ViewBuilder
    private func sheetContent(_ type: SheetType) -> some View {
        switch type {
        case .date:
            SessionDateSheet(start: $teamSession.startTime, end: $teamSession.endTime)
        case .athletePicker:
            LibraryPickerView<Athlete>(title: "Choose Athlete", emptyText: "No athletes yet", exclude: { athlete in
                teamSession.entries.contains { $0.athlete?.uuid == athlete.uuid }
            }) { athlete in
                teamSession.addAthlete(athlete, context: modelContext)
                sheetType = nil
            }
        case .newAthlete:
            newAthleteSheet()
        case .exercisePicker(let setIndex):
            LibraryPickerView<Exercise> { exercise in
                guard let newExercise = ExerciseLibrary.makeSessionExercise(from: exercise) else { return }
                exercise.lastUsedAt = .now
                teamSession.addExercise(newExercise, toSet: setIndex)
                sheetType = nil
            }
        case .exerciseBase(let setIndex, let exerciseIndex):
            SessionExerciseSheet(
                exercise: .init(get: {
                    teamSession.sets[setIndex].exercises[exerciseIndex]
                }, set: { newValue in
                    teamSession.sets[setIndex].exercises[exerciseIndex] = newValue
                }),
                showing: .init(get: {
                    if case .exerciseBase = sheetType { return true }
                    return false
                }, set: { newValue in
                    if !newValue {
                        teamSession.syncExercisePrescription(setIndex: setIndex, exerciseIndex: exerciseIndex)
                        sheetType = nil
                    }
                }),
                showData: false
            )
        }
    }

    @ViewBuilder
    private func newAthleteSheet() -> some View {
        NavigationStack {
            Form {
                TextField("Name", text: $newAthleteName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }.navigationTitle("New Athlete")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            sheetType = nil
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            let athlete = Athlete(name: newAthleteName)
                            modelContext.insert(athlete)
                            teamSession.addAthlete(athlete, context: modelContext)
                            sheetType = nil
                        } label: {
                            Label("Add", systemImage: "checkmark")
                        }.disabled(newAthleteName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
        }.presentationDetents([.medium])
    }
}
