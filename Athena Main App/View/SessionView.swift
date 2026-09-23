//
//  SessionView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import AudioToolbox
import SwiftData
import SwiftUI
internal import Combine

struct SessionView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    var title: String {
        if let indices {
            return session.sets[indices.routineSetIndex].name
        } else {
            return session.startTime.formatted(date: .numeric, time: .shortened)
        }
    }
    
    /// If true, data has been collected in some form for the session
    var hasData: Bool {
        !session.notes.isEmpty || session.sets.contains(where: { $0.exercises.contains(where: \.hasData) })
    }
    
    /// The current exercise, based on the current state of the indices field
    var currentExercise: Session.Exercise? {
        if let indices {
            return session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        }
        return nil
    }

    /// Pure traversal/phase/timer-duration logic over a snapshot of the session's sets.
    private var runner: SessionRunner {
        SessionRunner(sets: session.sets)
    }

    /// Snapshot of the live session state, sent to the watch whenever it changes.
    /// Returns nil when there's nothing to mirror (no active exercise, or the session is done).
    var activeSessionSnapshot: ActiveSessionSnapshot? {
        guard !session.finished, let indices, let exerciseState, let currentExercise else { return nil }
        let set = session.sets[indices.routineSetIndex]
        let recordsWeight: Bool
        let recordsDualSides: Bool
        let hasOffPhaseEntry: Bool
        let unitLabel: String
        switch currentExercise {
        case .generic(let d):
            recordsWeight = d.expected.dataType.hasWeight
            recordsDualSides = d.expected.sideType == .independent
            hasOffPhaseEntry = d.expected.dataType.hasTime && d.expected.sideType == .independent
            unitLabel = d.expected.setDetailText
        case .repeater:
            recordsWeight = true
            recordsDualSides = false
            hasOffPhaseEntry = false
            unitLabel = "reps"
        case .maxHang(let d):
            recordsWeight = true
            recordsDualSides = d.expected.isSingleArm
            hasOffPhaseEntry = false
            unitLabel = "s"
        case .campus:
            recordsWeight = false
            recordsDualSides = false
            hasOffPhaseEntry = false
            unitLabel = ""
        }
        // Suggested values only matter during the .rest form or the .off entry window; genericData
        // was already seeded by loadData(_:) when setState(newIndices:) ran, so this just reads it.
        let showsSuggestedData = exerciseState == .rest || (exerciseState == .off && hasOffPhaseEntry && timerEndDate == nil)
        return ActiveSessionSnapshot(
            sessionStartTime: session.startTime,
            routineName: session.routine?.name ?? session.routineName,
            setName: set.name,
            setIndex: indices.setExerciseIndex,
            setCount: currentExercise.numSets,
            exerciseName: currentExercise.name,
            exerciseDetailText: currentExercise.getDescription(setIndex: indices.exerciseSetIndex),
            phase: snapshotPhase(for: exerciseState),
            repCurrent: repeaterRep.current,
            repMax: repeaterRep.max,
            timerEndDate: timerEndDate,
            timerDuration: timerDuration / .seconds(1),
            recordsWeight: recordsWeight,
            recordsDualSides: recordsDualSides,
            hasOffPhaseEntry: hasOffPhaseEntry,
            unitLabel: unitLabel,
            suggestedNumLeft: showsSuggestedData ? genericData.numLeft : 0,
            suggestedNumRight: showsSuggestedData ? genericData.numRight : 0,
            suggestedWeightLeft: showsSuggestedData ? genericData.weightLeft : 0,
            suggestedWeightRight: showsSuggestedData ? genericData.weightRight : 0
        )
    }

    /// Maps this view's ExercisePhase to the shared, Codable DTO's Phase, keeping
    /// the Shared/ types free of any dependency on this view's private types.
    private func snapshotPhase(for state: ExercisePhase) -> ActiveSessionSnapshot.Phase {
        switch state {
        case .ready: return .ready
        case .on: return .on
        case .off: return .off
        case .rest: return .rest
        }
    }

    /// The background color of the view
    var background: some ShapeStyle {
        switch exerciseState {
        case .ready, .off:
            return .ready
        case .on:
            return .active
        case .rest:
            if timerDuration > .zero && progress <= 0.25 {
                return .rest.mix(with: .ready, by: 1.0 - (progress * 4.0), in: .perceptual)
            }
            return .rest
        case .none:
            return Color(uiColor: .systemGroupedBackground)
        }
    }
    
    /// If true, the timer is allowed to modify the state when it finishes
    var allowTimerNext: Bool {
        return exerciseState != .rest || timerNextOverride
    }
    
    /// Caches the most recent session of the related routine (if it exists)
    let prevSession: Session?
    
    @State private var audioManager = AudioManager.shared
    @State private var commandCenter = SessionCommandCenter.shared
    /// The main session of the view. Is a state to allow for easy edits to notes, sets, etc.
    @State private var session: Session
    /// The state variable. Determines which exercise and set is currently displayed.
    /// If nil, we are not in progress and the home page is shown.
    @State private var indices: ExerciseIndices? = nil
    /// Contains additional state information about the current exercise
    @State private var exerciseState: ExercisePhase? = nil
    @State private var repeaterRep: RepeaterRep = .zero
    /// Set to the start time of the timer (in seconds)
    @State private var timerDuration: Duration = .zero
    /// Tracks how many seconds have passed for the current timer
    @State private var elapsedSeconds: Duration = .zero
    /// For better interactivity precision
    @State private var elapsedMilliseconds: Int = 0
    /// The absolute end date of the current timer, if running. Lets the watch render a live
    /// countdown without any per-second WatchConnectivity traffic.
    @State private var timerEndDate: Date? = nil
    /// The current timer, if in use
    @State private var cancellable: Cancellable?
    /// If true, a data entry component for left and right should be used
    @State private var allowMultiSide: Bool = false
    /// Contains data in an indeterminate state that is loaded to and saved from for the current exercise
    @State private var genericData: ExerciseEntryDraft = .init()
    /// The current sheet that should be shown - if nil, nothing is shown
    @State private var sheetType: SheetType? = nil
    /// Used for editing song details
    @State private var song: Session.Song = .init()
    /// If true, the delete alert should be shown
    @State private var showAlert: Bool = false
    @State private var timerNextOverride: Bool = false
    @State private var deleteExercise: (Int, Int)? = nil

    init(session: Session) {
        self.session = session
        self.prevSession = session.routine?.sessions
            .filter({ $0 != session && $0.athlete?.uuid == session.athlete?.uuid })
            .sorted(by: { $0.startTime < $1.startTime })
            .last
    }
    
    var body: some View {
        mainView()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .background(background)
            .onChange(of: exerciseState, { oldValue, newValue in
                if oldValue == ExercisePhase.on && newValue == ExercisePhase.rest {
                    audioManager.playSystemSound(1428)
                }
            })
            .sensoryFeedback(.success, trigger: exerciseState, condition: { oldValue, newValue in
                oldValue == ExercisePhase.on && newValue == ExercisePhase.rest
            })
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
                        session.sets[deleteExercise.0].exercises.remove(at: deleteExercise.1)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .sheet(item: $sheetType, content: sheetView)
            .toolbar(content: buildToolbar)
            .onAppear {
                SessionConnectivity.shared.send(activeSessionSnapshot)
                SessionLiveActivity.shared.sync(activeSessionSnapshot)
                // Drop anything submitted while no session view was around to apply it, so it
                // can't fire late against whatever exercise happens to be on screen next.
                commandCenter.consume()
            }
            .onChange(of: activeSessionSnapshot) { _, newValue in
                SessionConnectivity.shared.send(newValue)
                SessionLiveActivity.shared.sync(newValue)
            }
            .onChange(of: commandCenter.pendingCommand) { _, newValue in
                handleRemoteCommand(newValue)
            }
            .onDisappear {
                SessionConnectivity.shared.send(nil)
                SessionLiveActivity.shared.sync(nil)
            }
    }
    
    @ViewBuilder
    func sheetView(_ t: SheetType) -> some View {
        switch t {
        case .date:
            SessionDateSheet(start: $session.startTime, end: $session.endTime)
        case .weight:
            Form {
                Stepper(value: $session.bodyWeight, in: 0...1000, step: 1) {
                    HStack {
                        Text("Body Weight: \(session.bodyWeight.lbsFormat)")
                    }
                }
            }.presentationDetents([.medium])
        case .exercise(let setIndex, let exerciseIndex):
            SessionExerciseSheet(exercise: .init(get: {
                session.sets[setIndex].exercises[exerciseIndex]
            }, set: { newValue in
                session.sets[setIndex].exercises[exerciseIndex] = newValue
            }), showing: .init(get: {
                switch sheetType {
                case .exercise(_, _):
                    return true
                default:
                    return false
                }
            }, set: { newValue in
                if !newValue {
                    sheetType = nil
                }
            }), showData: session.finished)
        case .notes:
            Form {
                TextField("Notes", text: $genericData.notes, axis: .vertical)
                    .lineLimit(10...14)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }.presentationDetents([.large])
        case .song:
            editSongSheet()
        case .campusMoves(let alt):
            campusMovesSheet(alt: alt)
        case .exercisePicker(let setIndex):
            LibraryPickerView<Exercise> { exercise in
                guard let newExercise = ExerciseLibrary.makeSessionExercise(from: exercise) else { return }
                exercise.lastUsedAt = .now
                session.sets[setIndex].exercises.append(newExercise)
                sheetType = .exercise(setIndex: setIndex, exerciseIndex: session.sets[setIndex].exercises.count - 1)
            }
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

    @ViewBuilder
    func campusMovesSheet(alt: Bool) -> some View {
        let campusType: Routine.CampusSets.Exercise = {
            if case .campus(let d) = currentExercise {
                return d.expected.type
            }
            return .maxLadder
        }()
        NavigationStack {
            Form {
                CampusBoardView(board: genericData.campusSet.board, exercise: campusType, moves: alt ? $genericData.movesAlt : $genericData.campusSet.moves)
            }.navigationTitle(alt ? "Alt Moves" : "Moves")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            if alt {
                                genericData.movesAlt = []
                            } else {
                                genericData.campusSet.moves = []
                            }
                        } label: {
                            Label("Clear", systemImage: "clear")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sheetType = nil
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                }
        }.presentationDetents([.large])
    }

    /// Sweeps for exercises added via the "New" submenu during this session that
    /// haven't been saved to the library yet, and links them. Run at finish time
    /// rather than on creation, so an exercise added and then immediately deleted
    /// mid-session never litters the library.
    private func linkNewExercisesToLibrary() {
        ExerciseLibrary.linkUnlinkedExercises(in: session, context: modelContext)
    }

    @ToolbarContentBuilder
    func buildToolbar() -> some ToolbarContent {
        if indices == nil {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    if !session.finished {
                        Button {
                            linkNewExercisesToLibrary()
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
                            sheetType = .weight
                        } label: {
                            Label("Edit Weight", systemImage: "scalemass")
                        }
                        Button {
                            song = session.standoutSong ?? .init()
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
                    Button {
                        next()
                    } label: {
                        Label("Start", systemImage: "play")
                    }
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    next(skip: true)
                } label: {
                    Text("Skip")
                }.disabled(nextIndices() == nil)
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if indices != nil {
                    stopAndResetTimer()
                    setState(newIndices: nil)
                } else if !hasData {
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
    
    @ViewBuilder
    func mainView() -> some View {
        switch currentExercise {
        case nil:
            SessionHomeView(session: session, sheetType: $sheetType, song: $song, deleteExercise: $deleteExercise, onSelect: { setState(newIndices: $0) }, onFinish: {
                linkNewExercisesToLibrary()
                session.endTime = .now
            })
        case .generic(let data):
            genericExerciseView(data)
        case .repeater(let data):
            repeaterExerciseView(data)
        case .maxHang(let data):
            maxHangExerciseView(data)
        case .campus(let data):
            campusExerciseView(data)
        }
    }
    
    @ViewBuilder
    func genericExerciseView(_ data: Session.GenericData) -> some View {
        VStack(alignment: .leading) {
            switch data.expected.dataType {
            case .time, .timeWeight:
                timedGenericExerciseView(data)
            case .rep, .repWeight:
                defaultGenericExerciseView(data)
            }
        }.padding()
    }
    
    @ViewBuilder
    func genericExerciseHeaderView(_ data: Session.GenericData) -> some View {
        let index = indices!.exerciseSetIndex
        Text(data.expected.name)
            .font(.system(size: data.expected.name.count > 16 ? 32 : 40))
            .bold()
        Text("Set \(index + 1)/\(data.expected.sets.count)")
            .font(.title)
            .fontWeight(.semibold)
        HStack {
            Text("\(data.expected.sets[index].text) \(data.expected.setDetailText)")
            Spacer()
            if data.expected.sideType == .independent && data.expected.dataType.hasTime {
                let isRight = exerciseState == .off ? !isTimerValid : repeaterRep.max > 0 && repeaterRep.current < 2
                Text(isRight ? "Right" : "Left")
                    .font(.title)
                    .fontWeight(.semibold)
            }
        }.font(.title)
            .fontWeight(.semibold)
        if exerciseState == .ready, let prevData = tryGetPrevGenericData(indices!) {
            genericPrevDataView(prevData.0.expected, prevData.1)
        }
    }
    
    @ViewBuilder
    func genericPrevDataView(_ prevData: Routine.GenericSets, _ prevDataSet: Session.GenericDataSet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(prevSession!.startTime.formatted(date: .numeric, time: .omitted)): \(prevDataSet.toString(prevData))")
                .font(.title3)
            if !prevDataSet.notes.isEmpty {
                Text(prevDataSet.notes)
            }
        }.italic()
    }
    
    @ViewBuilder
    func timedGenericExerciseView(_ data: Session.GenericData) -> some View {
        switch exerciseState {
        case .ready, .on:
            genericExerciseHeaderView(data)
            timerView(text: exerciseState == .ready ? "Ready" : "Active", textCountDown: exerciseState == .ready)
            Spacer()
            controlView {
                next()
            }
        case .off:
            genericExerciseHeaderView(data)
            if isTimerValid {
                timerView(text: "Ready")
                Spacer()
                controlView {
                    next()
                }
            } else {
                genericRecordView(data)
                Spacer()
                controlView {
                    confirmOffPhaseData()
                }
            }
        case .rest:
            genericExerciseHeaderView(data)
            genericRecordView(data)
            nextExerciseView()
            if timerDuration > .zero {
                timerView(text: "Rest")
            }
            Spacer()
            controlView {
                performNextAction()
            }
        default:
            Text("Invalid state for generic exercise")
        }
    }
    
    @ViewBuilder
    func defaultGenericExerciseView(_ data: Session.GenericData) -> some View {
        switch exerciseState {
        case .ready:
            genericExerciseHeaderView(data)
            Spacer()
            controlView {
                next()
            }
        case .rest:
            genericExerciseHeaderView(data)
            genericRecordView(data)
            nextExerciseView()
            if timerDuration > .zero {
                timerView(text: "Rest")
            }
            Spacer()
            controlView {
                performNextAction()
            }
        default:
            Text("Invalid state for generic exercise")
        }
    }
    
    @ViewBuilder
    func genericRecordView(_ data: Session.GenericData) -> some View {
        if data.expected.dataType.hasTime {
            let isRight = exerciseState == .off ? !isTimerValid : repeaterRep.max > 0 && repeaterRep.current < 2
            if isRight {
                HStack {
                    Stepper("\(genericData.numRight) \(data.expected.setDetailText)", value: $genericData.numRight, in: 0...1000, step: 1)
                    if data.expected.dataType.hasWeight {
                        Stepper(genericData.weightLeft.lbsFormat, value: $genericData.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                    }
                }.font(.title3).bold()
            } else {
                genericRecordSingleEntryView(data)
            }
        } else {
            if data.expected.sideType == .independent {
                Toggle("Different Side Values", isOn: $allowMultiSide)
                    .font(.title3)
                    .bold()
            }
            if data.expected.sideType == .independent && allowMultiSide {
                HStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Stepper("\(genericData.numLeft) \(data.expected.setDetailText)", value: $genericData.numLeft, in: 0...1000, step: 1)
                        if data.expected.dataType.hasWeight {
                            Stepper(genericData.weightLeft.lbsFormat, value: $genericData.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                        }
                    }
                    VStack(alignment: .trailing, spacing: 16) {
                        Stepper("\(genericData.numRight) \(data.expected.setDetailText)", value: $genericData.numRight, in: 0...1000, step: 1)
                        if data.expected.dataType.hasWeight {
                            Stepper(genericData.weightRight.lbsFormat, value: $genericData.weightRight, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                        }
                    }
                }.font(.title3).bold()
            } else {
                genericRecordSingleEntryView(data)
            }
        }
        editNotesButton()
    }
    
    @ViewBuilder
    func editNotesButton() -> some View {
        Button {
            sheetType = .notes
        } label: {
            HStack {
                Spacer()
                Text(genericData.notes.isEmpty ? "Add Notes" : "Edit Notes")
                Spacer()
            }
        }.buttonStyle(.bordered)
            .tint(.primary)
    }
    
    @ViewBuilder
    func genericRecordSingleEntryView(_ data: Session.GenericData) -> some View {
        HStack {
            Stepper("\(genericData.numLeft) \(data.expected.setDetailText)", value: $genericData.numLeft, in: 0...1000, step: 1)
            if data.expected.dataType.hasWeight {
                Stepper(genericData.weightLeft.lbsFormat, value: $genericData.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
            }
        }.font(.title3).bold()
    }
    
    @ViewBuilder
    func repeaterHeaderView(_ data: Session.RepeaterData) -> some View {
        let index = indices!.exerciseSetIndex
        HStack {
            Text(data.expected.tag)
            Spacer()
            Text("Set \(index + 1)/\(data.expected.sets.count)")
        }.font(.system(size: 32))
            .bold()
        if exerciseState != .rest {
            HStack {
                Text("\(data.expected.timeOn)s/\(data.expected.timeOff)s")
                Spacer()
                Text("\(data.expected.sets[index].weight.lbsFormat)")
            }.font(.title)
                .fontWeight(.semibold)
            HStack {
                Text("Rep")
                Spacer()
                Text("\(repeaterRep.current)/\(repeaterRep.max)")
            }.font(.title)
                .fontWeight(.semibold)
        }
        if exerciseState == .ready, let prevData = tryGetPrevRepeaterData(indices!) {
            repeaterPrevDataView(prevData)
        }
    }
    
    @ViewBuilder
    func repeaterPrevDataView(_ prevData: Session.RepeaterSet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(prevSession!.startTime.formatted(date: .numeric, time: .omitted)): \(prevData.text)")
                .font(.title3)
            if !prevData.notes.isEmpty {
                Text(prevData.notes)
            }
        }.italic()
    }
    
    @ViewBuilder
    func repeaterExerciseView(_ data: Session.RepeaterData) -> some View {
        var timerText: String {
            switch exerciseState {
            case .ready: return "Get Ready"
            case .on: return "On"
            case .off: return "Off"
            case .rest: return "Rest"
            default: return ""
            }
        }
        VStack(alignment: .leading) {
            repeaterHeaderView(data)
            if exerciseState == .rest {
                repeaterRecordView(data)
                nextExerciseView()
            }
            if timerDuration > .zero {
                timerView(text: timerText)
            }
            Spacer()
            controlView {
                if exerciseState == .rest {
                    performNextAction()
                } else if !allowTimerNext && timerDuration > .zero && elapsedSeconds < timerDuration {
                    timerNextOverride = true
                } else {
                    next()
                }
            }
        }.padding()
    }
    
    @ViewBuilder
    func repeaterRecordView(_ data: Session.RepeaterData) -> some View {
        HStack {
            Stepper("\(genericData.numLeft) reps", value: $genericData.numLeft, in: 0...1000, step: 1)
            Stepper(genericData.weightLeft.lbsFormat, value: $genericData.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
        }.font(.title3).bold()
        editNotesButton()
    }
    
    @ViewBuilder
    func maxHangHeaderView(_ data: Session.MaxHangData) -> some View {
        let index = indices!.exerciseSetIndex
        Text(data.expected.tag)
            .font(.system(size: data.expected.tag.count > 16 ? 32 : 40))
            .bold()
        Text("Set \(index + 1)/\(data.expected.sets.count)")
            .font(.title)
            .fontWeight(.semibold)
        if data.expected.isSingleArm {
            let isRight = exerciseState == .off ? !isTimerValid : repeaterRep.max > 0 && repeaterRep.current < 2
            HStack {
                Text(isRight ? data.expected.sets[index].textRight : data.expected.sets[index].textLeft)
                Spacer()
                Text(isRight ? "Right" : "Left")
                    .font(.title)
                    .fontWeight(.semibold)
            }.font(.title)
                .fontWeight(.semibold)
        } else {
            Text(data.expected.sets[index].textLeft)
                .font(.title)
                .fontWeight(.semibold)
        }
        if exerciseState == .ready, let prevData = tryGetPrevMaxHangData(indices!) {
            maxHangPrevDataView(prevData)
        }
    }
    
    @ViewBuilder
    func maxHangPrevDataView(_ prevData: Session.MaxHangSet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(prevSession!.startTime.formatted(date: .numeric, time: .omitted)): \(prevData.text)")
                .font(.title3)
            if !prevData.notes.isEmpty {
                Text(prevData.notes)
            }
        }.italic()
    }
    
    @ViewBuilder
    func maxHangExerciseView(_ data: Session.MaxHangData) -> some View {
        var timerText: String {
            switch exerciseState {
            case .ready: return "Get Ready"
            case .on: return "On"
            case .off: return "Get Ready (Alt)"
            case .rest: return "Rest"
            default: return ""
            }
        }
        VStack(alignment: .leading) {
            maxHangHeaderView(data)
            if exerciseState == .rest {
                maxHangRecordView(data)
                nextExerciseView()
            }
            if timerDuration > .zero {
                timerView(text: timerText, textCountDown: exerciseState != .on)
            }
            Spacer()
            controlView {
                if exerciseState == .rest {
                    performNextAction()
                } else if !allowTimerNext && timerDuration > .zero && elapsedSeconds < timerDuration {
                    timerNextOverride = true
                } else {
                    next()
                }
            }
        }.padding()
    }
    
    @ViewBuilder
    func maxHangRecordView(_ data: Session.MaxHangData) -> some View {
        if data.expected.isSingleArm {
            Toggle("Different Side Values", isOn: $allowMultiSide)
                .font(.title3)
                .bold()
        }
        if data.expected.isSingleArm && allowMultiSide {
            HStack {
                VStack(alignment: .leading, spacing: 16) {
                    Stepper("\(genericData.numLeft)s", value: $genericData.numLeft, in: 0...1000, step: 1)
                    Stepper(genericData.weightLeft.lbsFormat, value: $genericData.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                }
                VStack(alignment: .trailing, spacing: 16) {
                    Stepper("\(genericData.numRight)s", value: $genericData.numRight, in: 0...1000, step: 1)
                    Stepper(genericData.weightRight.lbsFormat, value: $genericData.weightRight, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
                }
            }.font(.title3).bold()
        } else {
            HStack() {
                Stepper("\(genericData.numLeft)s", value: $genericData.numLeft, in: 0...1000, step: 1)
                Stepper(genericData.weightLeft.lbsFormat, value: $genericData.weightLeft, in: -200...200, step: 5, format: .number.precision(.fractionLength(0)))
            }.font(.title3).bold()
        }
        editNotesButton()
    }

    @ViewBuilder
    func campusExerciseView(_ data: Session.CampusSetData) -> some View {
        VStack(alignment: .leading) {
            campusHeaderView(data)
            if exerciseState == .rest {
                campusRecordView(data)
                nextExerciseView()
            }
            if timerDuration > .zero {
                timerView(text: exerciseState == .ready ? "Get Ready" : "Rest")
            }
            Spacer()
            controlView {
                if exerciseState == .rest {
                    performNextAction()
                } else if !allowTimerNext && timerDuration > .zero && elapsedSeconds < timerDuration {
                    timerNextOverride = true
                } else {
                    next()
                }
            }
        }.padding()
    }

    @ViewBuilder
    func campusHeaderView(_ data: Session.CampusSetData) -> some View {
        let index = indices!.exerciseSetIndex
        Text(data.expected.type.text)
            .font(.system(size: data.expected.type.text.count > 16 ? 32 : 40))
            .bold()
        Text("Set \(index + 1)/\(data.expected.sets.count)")
            .font(.title)
            .fontWeight(.semibold)
        Text(data.expected.sets[index].text)
            .font(.title2)
            .fontWeight(.semibold)
        if exerciseState == .ready, let prevData = tryGetPrevCampusData(indices!) {
            campusPrevDataView(prevData)
        }
    }

    @ViewBuilder
    func campusPrevDataView(_ prevData: Session.CampusSetPair) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(prevSession!.startTime.formatted(date: .numeric, time: .omitted)): \(prevData.text)")
                .font(.title3)
            if !prevData.main.notes.isEmpty {
                Text(prevData.main.notes)
            }
        }.italic()
    }

    @ViewBuilder
    func campusRecordView(_ data: Session.CampusSetData) -> some View {
        Picker("Board/Edges", selection: $genericData.campusSet.board) {
            ForEach(CampusBoard.allCases, id: \.name) { board in
                Text(board.name).tag(board)
            }
        }.font(.title3).bold()
        Button {
            sheetType = .campusMoves(alt: false)
        } label: {
            Text(genericData.campusSet.moves.text)
                .font(.title3)
                .bold()
        }.buttonStyle(.bordered)
            .tint(.primary)
        if data.expected.type.canMirror {
            Button {
                sheetType = .campusMoves(alt: true)
            } label: {
                Text(genericData.movesAlt.text)
                    .font(.title3)
                    .bold()
            }.buttonStyle(.bordered)
                .tint(.primary)
        }
        editNotesButton()
    }

    @ViewBuilder
    func nextExerciseView() -> some View {
        if let nextIndices = nextIndices() {
            VStack(alignment: .leading, spacing: 0) {
                Text("Next Exercise")
                    .font(.title3)
                    .italic()
                let exercise = session.sets[nextIndices.routineSetIndex].exercises[nextIndices.setExerciseIndex]
                HStack {
                    Text(exercise.name)
                    Spacer()
                    Text(exercise.getText(setIndex: nextIndices.exerciseSetIndex))
                }.font(.title2)
                    .fontWeight(.semibold)
            }
            if let prevData = tryGetPrevGenericData(nextIndices) {
                genericPrevDataView(prevData.0.expected, prevData.1)
            } else if let prevData = tryGetPrevRepeaterData(nextIndices) {
                repeaterPrevDataView(prevData)
            } else if let prevData = tryGetPrevMaxHangData(nextIndices) {
                maxHangPrevDataView(prevData)
            } else if let prevData = tryGetPrevCampusData(nextIndices) {
                campusPrevDataView(prevData)
            }
        }
    }
    
    @ViewBuilder
    func timerView(text: String, textCountDown: Bool = true) -> some View {
        TimerRingView(text: text, textCountDown: textCountDown, timerDuration: timerDuration, elapsedSeconds: elapsedSeconds, progress: progress)
    }
    
    @ViewBuilder
    func controlView(nextAction: @escaping () -> Void) -> some View {
        SessionControlBar(isTimerRunning: isTimerValid, allowTimerNext: allowTimerNext, elapsedSeconds: elapsedSeconds, timerDuration: timerDuration, onPrev: prev, onToggle: toggleTimer, onNext: nextAction)
    }
    
    
    // ************** //
    // DATA FUNCTIONS //
    // ************** //
    
    func loadData(_ indices: ExerciseIndices?) -> ExerciseEntryDraft {
        runner.draft(at: indices, previous: PreviousSessionLookup(prevSession))
    }
    
    /// Applies a command received from the watch, exactly as if the phone's own matching
    /// button had been tapped. Pulled out of the body's .onChange closure since inlining this
    /// switch there made the modifier chain too complex for the type-checker.
    private func handleRemoteCommand(_ command: SessionCommand?) {
        guard indices != nil, let command else { return }
        switch command {
        case .toggleTimer:
            toggleTimer()
        case .prev:
            prev()
        case .next(let data):
            if let data {
                genericData.numLeft = data.numLeft
                genericData.numRight = data.numRight
                genericData.weightLeft = data.weightLeft
                genericData.weightRight = data.weightRight
                // Ensure toGeneric(_:useAlt:) actually honors the right-side value the watch
                // sent, rather than silently collapsing to the left value for independent-side
                // exercises. A no-op for exercises without independent sides, and a no-op for
                // dataType.hasTime cases (toGeneric already forces useAlt there regardless).
                // Skipped for campus: the watch has no way to enter moves, so this must not
                // silently flip mirroring on.
                if case .campus = currentExercise {} else {
                    allowMultiSide = true
                }
            }
            // Mirrors exactly what the phone's own controlView closure does in each phase:
            // .rest saves + maybe advances; .off's entry window saves + starts the get-ready
            // countdown (but doesn't advance yet); everything else (including .off's own
            // countdown) just advances.
            switch exerciseState {
            case .rest:
                performNextAction()
            case .off where timerEndDate == nil:
                confirmOffPhaseData()
            default:
                next()
            }
        }
        commandCenter.consume()
    }

    /// Saves the entered data, then either advances or arms the timer-skip override. Used by
    /// all four exercise types' .rest-phase "Next" controls (phone button and remote watch
    /// command alike), so there's exactly one implementation of "what Next does during rest."
    private func performNextAction() {
        trySaveData()
        if !allowTimerNext && timerDuration > .zero && elapsedSeconds < timerDuration {
            timerNextOverride = true
        } else {
            next()
        }
    }

    /// Confirms the side just finished (for independent-sided timed generic exercises) and
    /// starts the "get ready for the other side" countdown. Named so a remote watch command can
    /// call the identical code the phone's own off-phase confirm button calls.
    private func confirmOffPhaseData() {
        trySaveData()
        startTimer()
    }

    func trySaveData() {
        guard let indices else { return }
        SessionRunner.apply(genericData, at: indices, allowMultiSide: allowMultiSide, to: &session.sets)
    }
    
    func tryGetPrevGenericData(_ indices: ExerciseIndices) -> (Session.GenericData, Session.GenericDataSet)? {
        PreviousSessionLookup(prevSession).generic(at: indices)
    }
    
    func tryGetPrevRepeaterData(_ indices: ExerciseIndices) -> Session.RepeaterSet? {
        PreviousSessionLookup(prevSession).repeater(at: indices)
    }
    
    func tryGetPrevMaxHangData(_ indices: ExerciseIndices) -> Session.MaxHangSet? {
        PreviousSessionLookup(prevSession).maxHang(at: indices)
    }

    func tryGetPrevCampusData(_ indices: ExerciseIndices) -> Session.CampusSetPair? {
        PreviousSessionLookup(prevSession).campus(at: indices)
    }


    // ********************** //
    // CONTROL FLOW FUNCTIONS //
    // ********************** //
    
    /// Updates state to a different exercise
    func setState(newIndices: ExerciseIndices?) {
        if let newIndices {
            let newState = ExercisePhase.ready
            self.timerDuration = computeTimerDuration(indices: newIndices, exerciseState: newState)
            self.genericData = loadData(newIndices)
            if case .campus(let d) = session.sets[newIndices.routineSetIndex].exercises[newIndices.setExerciseIndex] {
                if newIndices.exerciseSetIndex < d.actual.count {
                    self.allowMultiSide = d.actual[newIndices.exerciseSetIndex].alt != nil
                } else if newIndices.exerciseSetIndex < d.expected.sets.count {
                    self.allowMultiSide = d.expected.sets[newIndices.exerciseSetIndex].doMirror && d.expected.type.canMirror
                }
            }
            self.exerciseState = newState
            self.indices = newIndices
            onStateChanged()
        } else {
            self.indices = nil
            self.exerciseState = nil
            self.timerDuration = .zero
            pauseTimer()
            self.genericData = .init()
            self.timerNextOverride = false
        }
    }
    
    /// Updates state for the same exerecise
    func setState(newState: ExercisePhase) {
        self.timerDuration = computeTimerDuration(indices: indices, exerciseState: newState)
        self.exerciseState = newState
        onStateChanged()
    }
    
    /// Housekeeping after changing exercises or exercise state
    private func onStateChanged() {
        // Reset flag
        self.timerNextOverride = false
        // Update repeater rep
        self.repeaterRep = nextRepeaterRep()
        // Start timer if needed
        switch currentExercise {
        case .generic(_):
            if exerciseState != .off {
                startTimer()
            }
        case .repeater(_), .maxHang(_), .campus(_):
            startTimer()
        case nil:
            pauseTimer()
        }
    }
    
    /// Computes the next state of the repeater rep field
    private func nextRepeaterRep() -> RepeaterRep {
        runner.repeaterRep(at: indices, phase: exerciseState, current: repeaterRep)
    }
    
    func prev() {
        stopAndResetTimer()
        if let newState = prevState() {
            setState(newState: newState)
        } else {
            setState(newIndices: prevIndices)
        }
    }
    
    func prevState() -> ExercisePhase? {
        runner.prevPhase(from: exerciseState)
    }
    
    var prevIndices: ExerciseIndices? {
        runner.prevIndices(from: indices)
    }
    
    func next(skip: Bool = false) {
        stopAndResetTimer()
        if !skip, let newState = nextState() {
            setState(newState: newState)
        } else {
            setState(newIndices: nextIndices())
        }
    }
    
    func nextState() -> ExercisePhase? {
        runner.nextPhase(at: indices, phase: exerciseState, rep: repeaterRep)
    }
    
    func nextIndices() -> ExerciseIndices? {
        runner.nextIndices(from: indices)
    }
    
    
    // *************** //
    // TIMER FUNCTIONS //
    // *************** //
    
    private func toggleTimer() {
        isTimerValid ? pauseTimer() : startTimer()
    }
    
    private func startTimer() {
        guard timerDuration > .zero else { return }
        timerEndDate = Date.now.addingTimeInterval((timerDuration - elapsedSeconds) / .seconds(1))
        cancellable = Timer
            .publish(every: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if newSecondPassed {
                    withAnimation(.easeInOut) {
                        if elapsedSeconds < timerDuration {
                            elapsedSeconds += .seconds(1.0)
                        }
                    } completion: {
                        if shouldStopTimer {
                            if allowTimerNext {
                                stopAndResetTimer()
                                // Go to next state if applicable
                                if timerDuration > .zero {
                                    next()
                                }
                            } else {
                                // Don't reset, keep showing 0:00 until handled
                                pauseTimer()
                            }
                        }
                    }
                }
                if !shouldStopTimer {
                    elapsedMilliseconds += 10
                }
            }
    }
    
    private var progress: Double {
        // Using milliseconds for smoother animation
        let elapsed: Duration = .milliseconds(elapsedMilliseconds)
        return (timerDuration - elapsed) / timerDuration
    }
    
    private var isTimerValid: Bool {
        cancellable != nil
    }

    private var shouldStopTimer: Bool {
        .milliseconds(elapsedMilliseconds) == timerDuration
    }
    
    private var newSecondPassed: Bool {
        elapsedMilliseconds > 0 && elapsedMilliseconds % 1000 == 0
    }
    
    private func pauseTimer() {
        cancellable?.cancel()
        cancellable = nil
        timerEndDate = nil
    }
    
    private func stopAndResetTimer() {
        pauseTimer()
        resetTimer()
    }
    
    private func resetTimer() {
        elapsedMilliseconds = 0
        withAnimation(.easeInOut) {
            elapsedSeconds = .zero
        }
    }
    
    private func computeTimerDuration(indices: ExerciseIndices?, exerciseState: ExercisePhase?) -> Duration {
        runner.timerDuration(at: indices, phase: exerciseState)
    }
    
    enum SheetType: Identifiable, Codable, Hashable, Equatable {
        var id: String {
            switch self {
            case .date:
                "date"
            case .weight:
                "weight"
            case .exercise(let setIndex, let exerciseIndex):
                "ex-\(setIndex)-\(exerciseIndex)"
            case .notes:
                "notes"
            case .song:
                "song"
            case .campusMoves(let alt):
                "campus-moves-\(alt)"
            case .exercisePicker(let setIndex):
                "exercise-picker-\(setIndex)"
            }
        }

        case date
        case weight
        case exercise(setIndex: Int, exerciseIndex: Int)
        case notes
        case song
        case campusMoves(alt: Bool)
        case exercisePicker(setIndex: Int)
    }
    
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        let routine = routines.first!
        let session: Session = {
            let session = Session(startTime: .now.addingTimeInterval(-700))
            session.routine = routine
            session.sets = routine.sets.map(Session.ExerciseSet.init)
            return session
        }()
        SessionView(session: session)
    }
}

#Preview("Fresh") {
    NavigationStack {
        SessionView(session: Session())
    }
}
