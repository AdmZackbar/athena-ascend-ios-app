//
//  SessionView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftData
import SwiftUI
internal import Combine

struct SessionView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    var title: String {
        if let routine = session.routine {
            return routine.name
        } else {
            return session.startTime.formatted(date: .numeric, time: .shortened)
        }
    }

    var hasData: Bool {
        !session.notes.isEmpty || !session.data.filter({ !$0.actualData.isEmpty }).isEmpty
    }

    /// The main session of the view. Is a state to allow for easy edits to notes, sets, etc.
    @State private var session: Session
    /// The current sheet that should be shown - if nil, nothing is shown
    @State private var sheetType: SheetType? = nil
    /// Used for editing song details
    @State private var song: Session.Song = .init(name: "", artist: "")
    /// If true, the delete alert should be shown
    @State private var showAlert: Bool = false
    @State private var timerNextOverride: Bool = false
    @State private var deleteExercise: ExerciseData.Position? = nil

    init(session: Session) {
        self.session = session
    }

    var body: some View {
        mainView()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .background(Color(uiColor: .systemGroupedBackground))
            .alert("Are you sure you want to delete this session?", isPresented: $showAlert, actions: {
                Button(role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            })
            .alert("Delete Exercise?", isPresented: .init(get: {
                deleteExercise != nil
            }, set: { newValue in
                if !newValue {
                    deleteExercise = nil
                }
            })) {
                Button(role: .destructive) {
                    if let deleteExercise {
                        session.data.filter({ $0.position == deleteExercise }).forEach(modelContext.delete)
                        session.data.removeAll(where: { $0.position == deleteExercise })
                        // Update positions of all later exercises to reflect the shift down
                        session.data
                            .filter { $0.position.superSetIndex == deleteExercise.superSetIndex && $0.position.setIndex > deleteExercise.setIndex }
                            .forEach { $0.position = .init(superSetIndex: $0.position.superSetIndex, setIndex: $0.position.setIndex - 1) }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .sheet(item: $sheetType, content: sheetView)
            .toolbar(content: buildToolbar)
    }

    @ViewBuilder
    func mainView() -> some View {
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
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                TextField("Notes", text: $session.notes, axis: .vertical)
                    .lineLimit((session.data.isEmpty ? 9 : 3)...12)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                if hasData {
                    Button {
                        session.endTime = .now
                    } label: {
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
                if session.athletes.count == 1 {
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
                    .sorted(by: { $0.position < $1.position })
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
        Button {
            sheetType = .exercise(data.position, athlete: data.athlete)
        } label: {
            HStack {
                ExerciseDataEntryView(data: data, headerType: headerType)
                Spacer()
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
            .contextMenu {
                if !session.finished && !data.expectedData.isEmpty {
                    Button {
                        // Go to exercise (set 1)
                        navigationStore.push(ViewType.sessionLive(session: data.session))
                    } label: {
                        Label("Start Exercise", systemImage: "play")
                    }
                }
            }
    }

    @ViewBuilder
    func sheetView(_ t: SheetType) -> some View {
        switch t {
        case .addExercise(let superSetIndex):
            // Preserve the existing exercise order (by position) rather than an
            // alphabetical Set ordering, so opening/closing this sheet without
            // reordering doesn't silently reshuffle the superset.
            let initialSelection = session.data
                .filter { $0.position.superSetIndex == superSetIndex }
                .sorted(by: { $0.position < $1.position })
                .compactMap { $0.exercise }
                .reduce(into: [Exercise]()) { result, exercise in
                    if !result.contains(exercise) {
                        result.append(exercise)
                    }
                }
            SelectExercisesSheet(initialSelection: initialSelection) { newSelection in
                let removedExercises = initialSelection.filter { !newSelection.contains($0) }
                // Remove all data for the removed exercises
                session.data.filter({ removedExercises.contains($0.exercise) && $0.position.superSetIndex == superSetIndex }).forEach(modelContext.delete)
                session.data.removeAll(where: { removedExercises.contains($0.exercise) && $0.position.superSetIndex == superSetIndex })
                // Add exercise data and update existing indices
                for index in 0..<newSelection.count {
                    let exercise = newSelection[index]
                    if initialSelection.contains(exercise) {
                        // Exists, update index
                        session.data.filter({ $0.exercise == exercise && $0.position.superSetIndex == superSetIndex })
                            .forEach({ $0.position.setIndex = index })
                    } else {
                        // New, need to create data
                        session.data += session.athletes.map { .init(exercise: exercise, session: session, athlete: $0, position: .init(superSetIndex: superSetIndex, setIndex: index)) }
                    }
                }
            }
        case .athlete:
            SelectAthletesSheet(initialSelection: session.athletes) { newSelection in
                let newAthletes = newSelection.filter { !session.athletes.contains($0) }
                let removedAthletes = session.athletes.filter { !newSelection.contains($0) }
                // Remove athletes and associated data from session
                session.athletes.removeAll(where: { removedAthletes.contains($0) })
                session.data.filter({ removedAthletes.contains($0.athlete) }).forEach(modelContext.delete)
                session.data.removeAll(where: { removedAthletes.contains($0.athlete) })
                // Add athletes and placeholder data to session
                session.athletes += newAthletes
                // Build one template entry per existing exercise slot so every new
                // athlete gets a matching row - falling back to the routine for slots
                // no athlete has data for yet, and preferring existing data (which may
                // have diverged from the routine) otherwise.
                var templates: [ExerciseData.Position: (exercise: Exercise, expectedData: [ExerciseData.DataSet])] = [:]
                if let routine = session.routine {
                    for d in routine.data {
                        templates[d.position] = (d.exercise, d.expectedData)
                    }
                }
                for d in session.data {
                    templates[d.position] = (d.exercise, d.expectedData)
                }
                for athlete in newAthletes {
                    session.data += templates.map { position, template in
                        ExerciseData(exercise: template.exercise, session: session, athlete: athlete, position: position, expectedData: template.expectedData)
                    }
                }
            }
        case .date:
            editDateSheet()
        case .exercise(let position, let athlete):
            ExerciseDataEditSheet(session: session, position: position, initialAthlete: athlete)
        case .song:
            editSongSheet()
        }
    }

    @ViewBuilder
    func editDateSheet() -> some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: .init(get: {
                    session.endTime ?? session.startTime
                }, set: { newValue in
                    session.endTime = newValue
                }), in: session.startTime..., displayedComponents: [.date, .hourAndMinute])
            }.navigationTitle("Edit Start/End Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            sheetType = nil
                        }
                    }
                }
        }.presentationDetents([.medium])
    }

    @ViewBuilder
    func editSongSheet() -> some View {
        NavigationStack {
            Form {
                Section("Song") {
                    TextField("Name", text: $song.name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    TextField("Artist", text: $song.artist)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
            }.navigationTitle("Edit Standout Song")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) {
                            session.standoutSong = nil
                            sheetType = nil
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            session.standoutSong = song
                            sheetType = nil
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }.disabled(song.name.isEmpty || song.artist.isEmpty)
                    }
                }
        }.presentationDetents([.medium, .large])
    }

    @ToolbarContentBuilder
    func buildToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                if !session.finished {
                    Button {
                        session.endTime = .now
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
                        song = session.standoutSong ?? .init(name: "", artist: "")
                        sheetType = .song
                    } label: {
                        Label("Edit Standout Song", systemImage: "music.note")
                    }
                    Button {
                        session.endTime = nil
                    } label: {
                        Label("Re-open Session", systemImage: "play")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    showAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            if !session.finished && session.data.contains(where: { !$0.expectedData.isEmpty }) {
                Button {
                    navigationStore.push(ViewType.sessionLive(session: session))
                } label: {
                    Label("Start", systemImage: "play")
                }
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if !hasData {
                    modelContext.delete(session)
                    dismiss()
                } else {
                    dismiss()
                }
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
        }
    }

    enum SheetType: Identifiable, Hashable {
        var id: String {
            switch self {
            case .addExercise(let superSetIndex):
                "add-exercise-\(superSetIndex)"
            case .athlete:
                "athlete"
            case .date:
                "date"
            case .exercise(let position, let athlete):
                "ex-\(position.superSetIndex)-\(position.setIndex)-\(athlete?.uuid.uuidString ?? "")"
            case .song:
                "song"
            }
        }

        case addExercise(superSetIndex: Int)
        case athlete
        case date
        case exercise(_ position: ExerciseData.Position, athlete: Athlete? = nil)
        case song
    }

}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Session.startTime) var sessions: [Session]
    NavigationStack {
        SessionView(session: sessions.first!)
    }.environmentObject(NavigationStore())
}

#Preview("Fresh", traits: .sampleData) {
    NavigationStack {
        SessionView(session: Session())
    }
}
