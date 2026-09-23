//
//  SessionHomeView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftUI

/// The home page shown when no exercise is in progress: session metadata, notes, and a summary
/// of every set/exercise with actions to start, resume, edit, or delete them.
struct SessionHomeView: View {
    @Bindable var session: Session
    @Binding var sheetType: RoutineSessionView.SheetType?
    @Binding var song: Session.Song
    @Binding var deleteExercise: (Int, Int)?
    /// Jumps into the given exercise/set, exactly as if its "Start"/"Resume"/"Re-start" button
    /// had been tapped.
    let onSelect: (ExerciseIndices) -> Void
    /// Links any exercises added via the "New" submenu to the library, then marks the session
    /// finished. Owned by the parent since the toolbar's own "Finish Session" action needs the
    /// identical link-then-finish sequence.
    let onFinish: () -> Void

    /// If true, data has been collected in some form for the session
    private var hasData: Bool {
        !session.notes.isEmpty || session.sets.contains(where: { $0.exercises.contains(where: \.hasData) })
    }

    var body: some View {
        if session.finished {
            closedHomePage()
        } else {
            activeHomePage()
        }
    }

    private func activeHomePage() -> some View {
        Form {
            Section {
                DatePicker("Start:", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                Stepper(value: $session.bodyWeight, in: 0...1000, step: 1) {
                    HStack {
                        Text("Body Weight: \(session.bodyWeight.lbsFormat)")
                    }
                }
                TextField("Notes", text: $session.notes, axis: .vertical)
                    .lineLimit((session.sets.isEmpty ? 9 : 3)...12)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                if hasData {
                    Button(action: onFinish) {
                        Label("Finish Session", systemImage: "checkmark")
                    }
                }
            } header: {
                if let routine = session.routine {
                    Text(routine.name)
                } else if let routineName = session.routineName {
                    Text(routineName)
                }
            }
            setSummaryView()
        }
    }

    @ViewBuilder
    private func closedHomePage() -> some View {
        Form {
            Section {
                TextField("Notes", text: $session.notes, axis: .vertical)
                    .lineLimit((session.sets.isEmpty ? 9 : 3)...12)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                Button {
                    song = session.standoutSong ?? .init()
                    sheetType = .song
                } label: {
                    if let standoutSong = session.standoutSong {
                        VStack(alignment: .leading) {
                            Text("Standout Song")
                                .bold()
                            Text(standoutSong.artist)
                                .font(.subheadline)
                                .italic()
                            Text(standoutSong.name)
                                .font(.headline)
                                .bold()
                        }
                    } else {
                        Label("Choose Standout Song...", systemImage: "music.note")
                    }
                }.buttonStyle(.plain)
            } header: {
                VStack(alignment: .leading) {
                    Text("Body Weight: \(session.bodyWeight.lbsFormat)")
                        .font(.subheadline)
                        .italic()
                    HStack {
                        if let routine = session.routine {
                            Text(routine.name)
                        } else if let routineName = session.routineName {
                            Text(routineName)
                        } else {
                            Text(session.startTime.formatted(date: .numeric, time: .shortened))
                        }
                        Spacer()
                        if let endTime = session.endTime {
                            Text(Duration.seconds(endTime.timeIntervalSince(session.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                        }
                    }
                }
            }
            setSummaryView()
        }
    }

    @ViewBuilder
    private func setSummaryView() -> some View {
        ForEach($session.sets.enumerated(), id: \.offset) { offset, $set in
            let setIndex = offset
            Section {
                ForEach(set.exercises.enumerated(), id: \.offset) { offset, exercise in
                    let exerciseIndex = offset
                    if !session.finished {
                        Menu {
                            if exercise.numCompletedSets == exercise.numSets {
                                Button {
                                    // Go to exercise (set 1)
                                    onSelect(.init(setIndex, exerciseIndex))
                                } label: {
                                    Label("Re-start Exercise", systemImage: "play")
                                }
                            } else if exercise.numCompletedSets > 0 {
                                Button {
                                    // Go to exercise (next set)
                                    onSelect(.init(setIndex, exerciseIndex, exercise.numCompletedSets))
                                } label: {
                                    Label("Resume Exercise", systemImage: "play")
                                }
                            } else {
                                Button {
                                    // Go to exercise (set 1)
                                    onSelect(.init(setIndex, exerciseIndex))
                                } label: {
                                    Label("Start Exercise", systemImage: "play")
                                }
                            }
                            Button {
                                sheetType = .exercise(setIndex: setIndex, exerciseIndex: exerciseIndex)
                            } label: {
                                Label("Edit Exercise", systemImage: "pencil")
                            }
                        } label: {
                            HStack {
                                SessionExerciseEntryView(exercise: exercise)
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", systemImage: "trash") {
                                    deleteExercise = (setIndex, exerciseIndex)
                                }.tint(.red)
                            }
                    } else {
                        Button {
                            sheetType = .exercise(setIndex: setIndex, exerciseIndex: exerciseIndex)
                        } label: {
                            HStack {
                                SessionExerciseEntryView(exercise: exercise)
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", systemImage: "trash") {
                                    deleteExercise = (setIndex, exerciseIndex)
                                }.tint(.red)
                            }
                    }
                }
            } header: {
                HStack {
                    if session.finished {
                        Text(set.name)
                    } else {
                        TextField("Set Name", text: $set.name)
                    }
                    Spacer()
                    if set.restTime > 0 {
                        Text("\(set.restTime)s Rest")
                    }
                    ExerciseSetHeaderMenu(
                        onPickFromLibrary: { sheetType = .exercisePicker(setIndex: setIndex) },
                        onAddNew: { exercise in
                            set.exercises.append(exercise)
                            sheetType = .exercise(setIndex: setIndex, exerciseIndex: set.exercises.count - 1)
                        },
                        onDeleteSet: { session.sets.remove(at: setIndex) }
                    )
                }
            }
        }
        if !session.finished {
            Button {
                session.sets.append(.init(base: .init()))
            } label: {
                Label("Add New Set", systemImage: "plus")
            }
        }
    }
}
