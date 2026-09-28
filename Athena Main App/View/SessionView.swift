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
        SessionHomeView(session: session, sheetType: $sheetType, song: $song, deleteExercise: $deleteExercise, onSelect: { _ in /* TODO */ }, onFinish: {
            session.endTime = .now
        })
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
    func sheetView(_ t: SheetType) -> some View {
        switch t {
        case .addExercise(let superSetIndex):
            let initialSelection = Set(session.data
                .filter { $0.position.superSetIndex == superSetIndex }
                .compactMap { $0.exercise })
                .sorted(by: { $0.name < $1.name })
            SelectExercisesSheet(initialSelection: initialSelection) { newSelection in
                let newExercises = newSelection.filter { !initialSelection.contains($0) }
                let removedExercises = initialSelection.filter { !newSelection.contains($0) }
                // Remove all data for the removed exercises
                session.data.removeAll(where: { removedExercises.contains($0.exercise) })
                // Add athlete placeholder data
                let nextSetIndex: Int = session.data
                    .filter { $0.position.superSetIndex == superSetIndex }
                    .map { $0.position.setIndex }
                    .max() ?? 0
                for athlete in session.athletes {
                    session.data += newExercises.enumerated().map { offset, exercise in
                        ExerciseData(exercise: exercise, session: session, athlete: athlete, position: .init(superSetIndex: superSetIndex, setIndex: nextSetIndex + offset))
                    }
                }
            }
        case .athlete:
            SelectAthletesSheet(initialSelection: session.athletes) { newSelection in
                let newAthletes = newSelection.filter { !session.athletes.contains($0) }
                let removedAthletes = session.athletes.filter { !newSelection.contains($0) }
                // Remove athletes and associated data from session
                session.athletes.removeAll(where: { removedAthletes.contains($0) })
                session.data.removeAll(where: { removedAthletes.contains($0.athlete) })
                // Add athletes and placeholder data to session
                session.athletes += newAthletes
                if let routine = session.routine {
                    for athlete in newAthletes {
                        session.data += routine.data.map { ExerciseData(exercise: $0.exercise, session: session, athlete: athlete, position: $0.position, expectedData: $0.expectedData) }
                    }
                }
            }
        case .exercise(let position, let athlete):
            ExerciseDataEditSheet(session: session, position: position, initialAthlete: athlete)
        case .song:
            editSongSheet()
        default:
            // TODO
            EmptyView()
        }
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
            if !session.finished && session.routine != nil {
                NavigationLink {
                    SessionLiveView(session: session)
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
            case .exercisePicker(let setIndex):
                "exercise-picker-\(setIndex)"
            }
        }

        case addExercise(superSetIndex: Int)
        case athlete
        case date
        case exercise(_ position: ExerciseData.Position, athlete: Athlete? = nil)
        case song
        case exercisePicker(setIndex: Int)
    }
    
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Session.startTime) var sessions: [Session]
    NavigationStack {
        SessionView(session: sessions.first!)
    }
}

#Preview("Fresh", traits: .sampleData) {
    NavigationStack {
        SessionView(session: Session())
    }
}
