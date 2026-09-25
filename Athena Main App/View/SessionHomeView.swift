//
//  SessionHomeView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftData
import SwiftUI

/// The home page shown when no exercise is in progress: session metadata, notes, and a summary
/// of every set/exercise with actions to start, resume, edit, or delete them.
struct SessionHomeView: View {
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    
    @Bindable var session: Session
    @Binding var sheetType: SessionView.SheetType?
    @Binding var song: Session.Song
    @Binding var deleteExercise: ExerciseData.Position?
    /// Jumps into the given exercise/set, exactly as if its "Start"/"Resume"/"Re-start" button
    /// had been tapped.
    let onSelect: (ExerciseIndices) -> Void
    /// Links any exercises added via the "New" submenu to the library, then marks the session
    /// finished. Owned by the parent since the toolbar's own "Finish Session" action needs the
    /// identical link-then-finish sequence.
    let onFinish: () -> Void

    /// If true, data has been collected in some form for the session
    private var hasData: Bool {
        !session.notes.isEmpty || session.data.contains(where: { !$0.actualData.isEmpty })
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
                // TODO athlete selection
//                Picker("Athlete:", selection: $session.athlete) {
//                    ForEach(athletes) { athlete in
//                        Text(athlete.name).tag(athlete as Athlete?)
//                    }
//                }
                DatePicker("Start:", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                TextField("Notes", text: $session.notes, axis: .vertical)
                    .lineLimit((session.data.isEmpty ? 9 : 3)...12)
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
                    .lineLimit((session.data.isEmpty ? 9 : 3)...12)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                Button {
                    song = session.standoutSong ?? .init(name: "", artist: "")
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
                    // TODO
//                    HStack {
//                        Text(session.athleteDisplayName)
//                        Spacer()
//                        Text(session.bodyWeight.lbsFormat)
//                    }.font(.subheadline)
//                        .italic()
                    HStack {
                        if let routine = session.routine {
                            Text(routine.name)
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
        ForEach($session.superSets.enumerated(), id: \.offset) { offset, $superSet in
            let superSetIndex = offset
            Section {
                ForEach(session.data
                    .filter { $0.position.superSetIndex == superSetIndex }
                    .sorted(by: { $0.position.setIndex < $1.position.setIndex })
                    .enumerated(), id: \.offset) { offset, data in
                    dataView(superSetIndex: superSetIndex, setIndex: offset, data: data)
                }
            } header: {
                HStack {
                    if session.finished {
                        Text(superSet.name)
                    } else {
                        TextField("Set Name", text: $superSet.name)
                    }
                    Spacer()
                    if superSet.restTime > 0 {
                        Text("\(superSet.restTime)s Rest")
                    }
                    // TODO
//                    ExerciseSetHeaderMenu(
//                        onPickFromLibrary: { sheetType = .exercisePicker(setIndex: setIndex) },
//                        onAddNew: { exercise in
//                            set.exercises.append(exercise)
//                            sheetType = .exercise(setIndex: setIndex, exerciseIndex: set.exercises.count - 1)
//                        },
//                        onDeleteSet: { session.sets.remove(at: setIndex) }
//                    )
                }
            }
        }
        if !session.finished {
            // TODO
//            Button {
//                session.sets.append(.init(base: .init()))
//            } label: {
//                Label("Add New Set", systemImage: "plus")
//            }
        }
    }
    
    @ViewBuilder
    private func dataView(superSetIndex: Int, setIndex: Int, data: ExerciseData) -> some View {
        let exercise = data.exercise
        if !session.finished {
            Menu {
                if !data.expectedData.isEmpty {
                    if data.actualData.count >= data.expectedData.count {
                        Button {
                            // Go to exercise (set 1)
                            onSelect(.init(superSetIndex, setIndex))
                        } label: {
                            Label("Re-start Exercise", systemImage: "play")
                        }
                    } else if !data.actualData.isEmpty {
                        Button {
                            // Go to exercise (next set)
                            onSelect(.init(superSetIndex, setIndex, data.actualData.count))
                        } label: {
                            Label("Resume Exercise", systemImage: "play")
                        }
                    } else {
                        Button {
                            // Go to exercise (set 1)
                            onSelect(.init(superSetIndex, setIndex))
                        } label: {
                            Label("Start Exercise", systemImage: "play")
                        }
                    }
                }
                Button {
                    sheetType = .exercise(setIndex: superSetIndex, exerciseIndex: setIndex)
                } label: {
                    Label("Edit Exercise", systemImage: "pencil")
                }
            } label: {
                HStack {
                    // TODO
//                    SessionExerciseEntryView(exercise: exercise)
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash") {
                        deleteExercise = data.position
                    }.tint(.red)
                }
        } else {
            Button {
                sheetType = .exercise(setIndex: superSetIndex, exerciseIndex: setIndex)
            } label: {
                HStack {
                    // TODO
//                    SessionExerciseEntryView(exercise: exercise)
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash") {
                        deleteExercise = data.position
                    }.tint(.red)
                }
        }
    }
}
