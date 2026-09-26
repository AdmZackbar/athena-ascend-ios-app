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
                .onAppear {
                    if session.superSets.isEmpty {
                        session.superSets.append(.init(name: "Main Set"))
                    }
                }
        }
    }

    private func activeHomePage() -> some View {
        Form {
            Section {
                Button {
                    sheetType = .athlete
                } label: {
                    HStack {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                        if session.athletes.count > 1 {
                            VStack(alignment: .leading) {
                                Text("Athletes")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(session.athletes.map(\.name).sorted().joined(separator: ", "))
                            }
                        } else if let athlete = session.athletes.first {
                            VStack(alignment: .leading) {
                                Text("Athlete")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(athlete.fullName ?? athlete.name)
                            }
                        } else {
                            Text("No Athletes")
                                .italic()
                        }
                        Spacer()
                    }
                }.buttonStyle(.plain)
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
                DatePicker("Start", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
            }
            dataView()
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
                // Only show song for single athlete sessioons
                if athletes.count == 1 {
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
                }
            } header: {
                VStack(alignment: .leading) {
                    if session.athletes.count > 1 {
                        Text(session.athletes.map { $0.name }.sorted().joined(separator: ", "))
                            .font(.subheadline)
                            .italic()
                    } else if let athlete = session.athletes.first {
                        Text(athlete.fullName ?? athlete.name)
                            .font(.subheadline)
                            .italic()
                    }
                    HStack {
                        Text(session.startTime.formatted(date: .numeric, time: .shortened))
                        Spacer()
                        if let endTime = session.endTime {
                            Text(Duration.seconds(endTime.timeIntervalSince(session.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                        }
                    }
                }
            }
            dataView()
        }
    }
    
    @ViewBuilder
    func dataView() -> some View {
        if session.athletes.count > 1 {
            multiAthleteDataView()
        } else if !session.athletes.isEmpty {
            singleAthleteDataView()
        } else {
            Section("Data") {
                ContentUnavailableView("Add athletes to view and set data", systemImage: "person")
            }
        }
    }
    
    @ViewBuilder
    func multiAthleteDataView() -> some View {
        // TODO handle routines - need to keep structure
        // No need to structure exercises
        let groupedData: [ExerciseData.Position: [ExerciseData]] = .init(grouping: session.data, by: { $0.position })
        ForEach(groupedData.sorted(by: { ($0.key.superSetIndex, $0.key.setIndex) < ($1.key.superSetIndex, $1.key.setIndex) }),
            id: \.key.hashValue) { key, athleteData in
                Section {
                    ForEach(athleteData.sorted(by: { $0.athlete.name < $1.athlete.name })) { d in
                        dataView(d, headerType: .athleteName)
                    }
                } header: {
                    HStack {
                        Text(athleteData.first!.exercise.name)
                        Spacer()
                        Button(role: .destructive) {
                            deleteExercise = key
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
        }
        if !session.finished {
            Button {
                // Adding all exercises to default main set
                sheetType = .addExercise(superSetIndex: 0)
            } label: {
                Label("Add/Remove Exercises...", systemImage: "pencil")
            }
        }
    }
    
    @ViewBuilder
    func singleAthleteDataView() -> some View {
        ForEach($session.superSets.enumerated(), id: \.offset) { offset, $superSet in
            let superSetIndex = offset
            Section {
                ForEach(session.data.filter { $0.position.superSetIndex == superSetIndex }
                    .sorted(by: { $0.position.setIndex < $1.position.setIndex })
                    .enumerated(), id: \.offset) { offset, data in
                        dataView(data, headerType: .exerciseName)
                            .swipeActions {
                                Button("Delete", systemImage: "trash") {
                                    deleteExercise = data.position
                                }.tint(.red)
                            }
                }
                if !session.finished {
                    Button {
                        sheetType = .addExercise(superSetIndex: superSetIndex)
                    } label: {
                        Label("Add/Remove Exercises...", systemImage: "pencil")
                    }
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
                }
            }
        }
    }
    
    @ViewBuilder
    private func dataView(_ data: ExerciseData, headerType: ExerciseDataEntryView.HeaderType) -> some View {
        if !session.finished {
            Menu {
                if data.expectedData.isEmpty {
                    if data.actualData.count >= data.expectedData.count {
                        Button {
                            // Go to exercise (set 1)
                            onSelect(data.position.exerciseIndices)
                        } label: {
                            Label("Re-start Exercise", systemImage: "play")
                        }
                    } else if !data.actualData.isEmpty {
                        Button {
                            // Go to exercise (next set)
                            onSelect(.init(data.position.superSetIndex, data.position.setIndex, data.actualData.count))
                        } label: {
                            Label("Resume Exercise", systemImage: "play")
                        }
                    } else {
                        Button {
                            // Go to exercise (set 1)
                            onSelect(data.position.exerciseIndices)
                        } label: {
                            Label("Start Exercise", systemImage: "play")
                        }
                    }
                }
                Button {
                    sheetType = .exercise(data.position, athlete: data.athlete)
                } label: {
                    Label("Edit Exercise", systemImage: "pencil")
                }
            } label: {
                HStack {
                    ExerciseDataEntryView(data: data, headerType: headerType)
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        } else {
            Button {
                sheetType = .exercise(data.position)
            } label: {
                HStack {
                    ExerciseDataEntryView(data: data, headerType: headerType)
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
}

extension ExerciseData.Position {
    var exerciseIndices: ExerciseIndices {
        .init(self.superSetIndex, self.setIndex)
    }
}
