//
//  RoutineSessionView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftData
import SwiftUI
internal import Combine

struct RoutineSessionView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    let readyTime: Duration = .seconds(10)
    
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
    
    /// The exercise that will be moved to next, if applicable.
    /// Can be the same as the current exercise if the state of the exercise is different
    var nextExercise: Session.Exercise? {
        if let nextIndices = nextIndices() {
            return session.sets[nextIndices.routineSetIndex].exercises[nextIndices.setExerciseIndex]
        }
        return nil
    }
    
    /// The background color of the view
    var background: some ShapeStyle {
        switch exerciseState {
        case .ready, .off:
            return .ready
        case .on:
            return .active
        case .rest:
            return .rest
        case .none:
            return Color(uiColor: .systemGroupedBackground)
        }
    }
    
    /// If true, the timer is allowed to modify the state when it finishes
    var allowTimerNext: Bool {
        return exerciseState != .rest
    }
    
    /// The main session of the view. Is a state to allow for easy edits to notes, sets, etc.
    @State private var session: Session
    /// The state variable. Determines which exercise and set is currently displayed.
    /// If nil, we are not in progress and the home page is shown.
    @State private var indices: ExerciseIndices? = nil
    /// Contains additional state information about the current exercise
    @State private var exerciseState: ExerciseState? = nil
    @State private var repeaterRep: RepeaterRep = .zero
    /// Set to the start time of the timer (in seconds)
    @State private var timerDuration: Duration = .seconds(0)
    /// Tracks how many seconds have passed for the current timer
    @State private var elapsedSeconds: Duration = .seconds(0)
    /// For better interactivity precision
    @State private var elapsedMilliseconds: Int = 0
    /// The current timer, if in use
    @State private var cancellable: Cancellable?
    /// If true, data entry should be shown (in addition to prev/next buttons)
    @State private var showNext: Bool = false
    /// Contains data in an indeterminate state that is loaded to and saved from for the current exercise
    @State private var genericData: GenericDataSet = .init()
    /// The current sheet that should be shown - if nil, nothing is shown
    @State private var sheetType: SheetType? = nil
    /// Used for editing song details
    @State private var song: Session.Song = .init()
    /// If true, the delete alert should be shown
    @State private var showAlert: Bool = false
    
    init(session: Session) {
        self.session = session
    }
    
    var body: some View {
        mainView()
            .navigationTitle(session.startTime.formatted(date: .numeric, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .background(background)
            .alert("Are you sure you want to delete this session?", isPresented: $showAlert, actions: {
                Button(role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            })
            .sheet(item: $sheetType) { t in
                switch t {
                case .date:
                    Form {
                        DatePicker("Start:", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End:", selection: .init(get: {
                            session.endTime ?? .now
                        }, set: { newValue in
                            session.endTime = newValue
                        }), displayedComponents: [.date, .hourAndMinute])
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
                            .lineLimit(3...6)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }.presentationDetents([.medium, .large])
                case .song:
                    editSongSheet()
                }
            }
            .toolbar(content: buildToolbar)
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
        if indices == nil {
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
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if indices != nil {
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
        if let currentExercise {
            switch currentExercise {
            case .generic(let data):
                genericExerciseView(data)
            case .repeater(let data):
                // TODO
                switch exerciseState {
                case .rest:
                    repeaterRestView()
                default:
                    repeaterMainView()
                }
            case .maxHang(let data):
                maxHangExerciseView(data)
            }
        } else if session.finished {
            closedHomePage()
        } else {
            activeHomePage()
        }
    }
    
    func activeHomePage() -> some View {
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
                    Button {
                        session.endTime = .now
                        dismiss()
                    } label: {
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
    func closedHomePage() -> some View {
        Form {
            Section {
                TextField("Notes", text: $session.notes, axis: .vertical)
                    .lineLimit(4...8)
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
    func setSummaryView() -> some View {
        ForEach($session.sets.enumerated(), id: \.offset) { offset, $set in
            let setIndex = offset
            Section {
                ForEach(set.exercises.enumerated(), id: \.offset) { offset, exercise in
                    let exerciseIndex = offset
                    if !session.finished {
                        Menu {
                            Button {
                                // Go to exercise
                                setState(newIndices: .init(setIndex, exerciseIndex))
                            } label: {
                                Label("Start Exercise", systemImage: "play")
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
                    } else {
                        Button {
                            sheetType = .exercise(setIndex: setIndex, exerciseIndex: exerciseIndex)
                        } label: {
                            HStack {
                                SessionExerciseEntryView(exercise: exercise)
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                if !session.finished {
                    HStack {
                        Menu {
                            Button("Basic") {
                                set.exercises.append(.generic(.init(expected: .init())))
                                sheetType = .exercise(setIndex: setIndex, exerciseIndex: set.exercises.count - 1)
                            }
                            Button("Repeater") {
                                set.exercises.append(.repeater(.init(expected: .init())))
                                sheetType = .exercise(setIndex: setIndex, exerciseIndex: set.exercises.count - 1)
                            }
                            Button("Max Hang") {
                                set.exercises.append(.maxHang(.init(expected: .init())))
                                sheetType = .exercise(setIndex: setIndex, exerciseIndex: set.exercises.count - 1)
                            }
                        } label: {
                            Label("Add Exercise...", systemImage: "plus")
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
                    Menu {
                        Button(role: .destructive) {
                            session.sets.remove(at: setIndex)
                        } label: {
                            Label("Delete Set", systemImage: "trash")
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                }
            } footer: {
                
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
    
    @ViewBuilder
    func genericExerciseView(_ data: Session.GenericData) -> some View {
        let exerciseIndex = indices!.exerciseSetIndex
        VStack(alignment: .leading) {
            Text(data.expected.name)
                .font(.title)
                .bold()
            HStack {
                Text("Set \(exerciseIndex + 1)/\(data.expected.sets.count)")
                Spacer()
                Text("\(data.expected.sets[exerciseIndex].text) \(data.expected.setDetailText)")
            }.font(.title2)
                .fontWeight(.semibold)
            if !showNext {
                Button("Complete") {
                    showNext = true
                    startTimer()
                }.buttonStyle(.borderedProminent)
            } else {
                VStack {
                    Stepper(value: $genericData.numLeft, in: 0...1000) {
                        Text("\(genericData.numLeft) \(data.expected.setDetailText)")
                    }
                    switch data.expected.dataType {
                    case .repWeight, .timeWeight:
                        Stepper(value: $genericData.weightLeft, in: -200...200, step: 5) {
                            HStack {
                                TextField("", value: $genericData.weightLeft, format: .number.precision(.fractionLength(0...2)))
                                    .keyboardType(.decimalPad)
                                Text("lbs")
                            }
                        }
                    default:
                        EmptyView()
                    }
                }.font(.title2)
                    .fontWeight(.semibold)
                    .frame(width: 240)
                Button {
                    sheetType = .notes
                } label: {
                    if genericData.notes.isEmpty {
                        Text("Add Notes...")
                    } else {
                        Text(genericData.notes)
                    }
                }.buttonStyle(.plain)
                    .font(.body)
                    .italic()
                timerView(text: "Rest")
                    .padding()
            }
            Spacer()
            if showNext {
                HStack {
                    Button("Prev") {
                        // Don't save when going back
                        prev()
                    }.buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Next") {
                        // Save before continuing
                        saveData(indices!)
                        next()
                    }.buttonStyle(.borderedProminent)
                }
            }
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func repeaterMainView() -> some View {
        let text: String = {
            switch exerciseState {
            case .ready:
                return "Get Ready"
            case .on:
                return "On"
            case .off:
                return "Off"
            default:
                return "N/A"
            }
        }()
        let setIndex = indices!.exerciseSetIndex
        let currentRep = repeaterRep.current
        let maxRep = repeaterRep.max
        VStack(alignment: .center, spacing: 8) {
            Spacer()
            if case .repeater(let d) = currentExercise {
                let numReps = d.expected.sets[setIndex].numReps
                HStack {
                    Text(d.expected.tag)
                    Spacer()
                    Text("[\(setIndex + 1)/\(d.expected.sets.count)]")
                }.font(.system(size: 36))
                    .bold()
                HStack {
                    Text("\(d.expected.timeOn)s/\(d.expected.timeOff)s")
                    Spacer()
                    Text("\(d.expected.sets[setIndex].weight.lbsFormat)")
                }.font(.system(size: 30))
                    .fontWeight(.semibold)
                HStack {
                    Text("Rep")
                    Spacer()
                    Text("\(currentRep)/\(maxRep)")
                }.font(.system(size: 30))
                    .fontWeight(.semibold)
            } else {
                // Shouldn't be possible
                Text(currentExercise?.description ?? "No Current Exercise")
                    .font(.title)
                    .bold()
            }
            timerView(text: text)
                .padding()
            Button {
                exerciseState = .rest
            } label: {
                Text("Record Data")
            }
            Spacer()
            controlView()
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func repeaterRestView() -> some View {
        VStack {
            switch nextExercise {
            case .repeater(let d):
                let setIndex = nextIndices()!.exerciseSetIndex
                Text("Next Exercise")
                HStack {
                    Text(d.expected.tag)
                    Spacer()
                    Text("[\(setIndex + 1)/\(d.expected.sets.count)]")
                }.font(.system(size: 36))
                    .bold()
                HStack {
                    Text("\(d.expected.timeOn)s/\(d.expected.timeOff)s")
                    Spacer()
                    Text("\(d.expected.sets[setIndex].weight.lbsFormat)")
                }.font(.system(size: 30))
                    .fontWeight(.semibold)
            case nil:
                Text("No More Sets")
            default:
                // TODO
                Text(nextExercise!.description)
            }
            ZStack {
                RingShape(progress: 1.0)
                    .stroke(.secondary, lineWidth: 8)
                RingShape(progress: 1.0 - progress)
                    .stroke(.primary, style: .init(lineWidth: 12, lineCap: .round))
                VStack(spacing: 0) {
                    Text("Rest")
                        .font(.system(size: 40))
                        .bold()
                    Text(timerDuration - elapsedSeconds, format: .time(pattern: .minuteSecond(padMinuteToLength: 2)))
                        .contentTransition(.numericText())
                        .monospaced()
                        .font(.system(size: 60))
                        .bold()
                }
            }.padding()
            VStack {
                HStack {
                    Stepper(value: $genericData.numLeft, in: 0...1000) {
                        Text("\(genericData.numLeft) reps")
                    }
                    Spacer()
                    Stepper(value: $genericData.weightLeft, in: -200...200, step: 5) {
                        HStack {
                            TextField("", value: $genericData.weightLeft, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }
                }.font(.title2)
                    .bold()
                Button {
                    sheetType = .notes
                } label: {
                    HStack {
                        Text(genericData.notes.isEmpty ? "Add Notes..." : genericData.notes)
                            .lineLimit(3)
                        Spacer()
                    }.contentShape(Rectangle())
                        .font(.headline)
                        .italic()
                }
                Button("Save") {
                    // Save recorded data
                    saveData(indices!)
                }
            }
            Spacer()
            HStack {
                Button("Prev") {
                    prev()
                }
                Spacer()
                Button("Next") {
                    next()
                }
            }
        }.padding()
    }
    
    @ViewBuilder
    func maxHangExerciseView(_ data: Session.MaxHangData) -> some View {
        // TODO
        restAndRecordView()
    }
    
    @ViewBuilder
    func maxHangView(_ str: String) -> some View {
        VStack(alignment: .center) {
            Spacer()
            Text(currentExercise!.description)
                .font(.title)
                .bold()
            timerView(text: str)
                .padding()
            Spacer()
            controlView()
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func restAndRecordView() -> some View {
        VStack(alignment: .center) {
            Text(currentExercise!.getDescription(setIndex: indices!.exerciseSetIndex))
            timerView(text: "Rest")
                .padding()
            recordView()
            Spacer()
            controlView()
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func recordView() -> some View {
        switch currentExercise {
        case .generic(let d):
            VStack {
                Stepper(value: $genericData.numLeft, in: 0...1000) {
                    Text("\(genericData.numLeft) \(d.expected.setDetailText)")
                }
                switch d.expected.dataType {
                case .repWeight, .timeWeight:
                    Stepper(value: $genericData.weightLeft, in: -200...200, step: 5) {
                        HStack {
                            TextField("", value: $genericData.weightLeft, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }
                default:
                    EmptyView()
                }
                Button {
                    sheetType = .notes
                } label: {
                    HStack {
                        Text(genericData.notes.isEmpty ? "Add Notes..." : genericData.notes)
                            .lineLimit(3)
                        Spacer()
                    }.contentShape(Rectangle())
                        .font(.headline)
                        .italic()
                }
                Button("Save") {
                    // Save recorded data
                    saveData(indices!)
                }
            }
        case .repeater(_):
            VStack {
                Stepper(value: $genericData.numLeft, in: 0...100) {
                    Text("\(genericData.numLeft) reps")
                }
                Stepper(value: $genericData.weightLeft, in: -200...200, step: 5) {
                    HStack {
                        TextField("", value: $genericData.weightLeft, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                        Text("lbs")
                    }
                }
                Button {
                    sheetType = .notes
                } label: {
                    HStack {
                        Text(genericData.notes.isEmpty ? "Add Notes..." : genericData.notes)
                            .lineLimit(3)
                        Spacer()
                    }.contentShape(Rectangle())
                        .font(.headline)
                        .italic()
                }
                Button("Save") {
                    // Save recorded data
                    saveData(indices!)
                }
            }
        case .maxHang(_):
            VStack {
                Stepper(value: $genericData.numLeft, in: 0...30) {
                    Text("\(genericData.numLeft) seconds")
                }
                Stepper(value: $genericData.weightLeft, in: -200...200, step: 5) {
                    HStack {
                        TextField("", value: $genericData.weightLeft, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                        Text("lbs")
                    }
                }
                Button {
                    sheetType = .notes
                } label: {
                    HStack {
                        Text(genericData.notes.isEmpty ? "Add Notes..." : genericData.notes)
                            .lineLimit(3)
                        Spacer()
                    }.contentShape(Rectangle())
                        .font(.headline)
                        .italic()
                }
                Button("Save") {
                    // Save recorded data
                    saveData(indices!)
                }
            }
        case nil:
            EmptyView()
        }
    }
    
    @ViewBuilder
    func timerView(text: String) -> some View {
        ZStack {
            RingShape(progress: 1.0)
                .stroke(.secondary, lineWidth: 8)
            RingShape(progress: 1.0 - progress)
                .stroke(.primary, style: .init(lineWidth: 12, lineCap: .round))
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 40))
                    .bold()
                Text(timerDuration - elapsedSeconds, format: .time(pattern: .minuteSecond(padMinuteToLength: 2)))
                    .contentTransition(.numericText())
                    .monospaced()
                    .font(.system(size: 60))
                    .bold()
            }
        }
    }
    
    @ViewBuilder
    func controlView() -> some View {
        HStack(spacing: 16) {
            Spacer()
            Button {
                prev()
            } label: {
                Image(systemName: "arrowshape.backward.circle")
                    .font(.system(size: 64))
            }
            Button {
                toggleTimer()
            } label: {
                Image(systemName: isTimerValid ? "pause.circle" : "play.circle")
                    .font(.system(size: 96))
            }.disabled(elapsedSeconds >= timerDuration)
            Button {
                next(skip: true)
            } label: {
                Image(systemName: "arrowshape.forward.circle")
                    .font(.system(size: 64))
            }
            Spacer()
        }.buttonStyle(.plain)
    }
    
    
    // ************** //
    // DATA FUNCTIONS //
    // ************** //
    
    func loadData(_ indices: ExerciseIndices?) -> GenericDataSet {
        guard let indices else { return .init() }
        let exercise = session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex], format: d.expected)
            } else {
                // Load from expected
                return .init(numLeft: d.expected.sets[indices.exerciseSetIndex].avg)
            }
        case .repeater(let d):
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex])
            } else {
                // Load from expected
                let expected = d.expected.sets[indices.exerciseSetIndex]
                return .init(numLeft: expected.numReps, weightLeft: expected.weight)
            }
        case .maxHang(let d):
            if indices.exerciseSetIndex < d.actual.count {
                // Load from current data
                return .init(d.actual[indices.exerciseSetIndex])
            } else {
                // Load from expected
                let expected = d.expected.sets[indices.exerciseSetIndex]
                return .init(side: expected.side, numLeft: expected.target, weightLeft: expected.weight)
            }
        }
    }
    
    func saveData(_ indices: ExerciseIndices) {
        let exercise = session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            var newActual: [Session.GenericDataSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = genericData.toGeneric(d.expected, useAlt: false)
            } else {
                newActual.append(genericData.toGeneric(d.expected, useAlt: false))
            }
            session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .generic(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .repeater(let d):
            var newActual: [Session.RepeaterSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = genericData.toRepeater()
            } else {
                newActual.append(genericData.toRepeater())
            }
            session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .repeater(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .maxHang(let d):
            var newActual: [Session.MaxHangSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = genericData.toMaxHang()
            } else {
                newActual.append(genericData.toMaxHang())
            }
            session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .maxHang(.init(expected: d.expected, actual: newActual, notes: d.notes))
        }
    }
    
    
    // ********************** //
    // CONTROL FLOW FUNCTIONS //
    // ********************** //
    
    /// Updates state to a different exercise
    func setState(newIndices: ExerciseIndices?) {
        let newState = ExerciseState.ready
        self.timerDuration = computeTimerDuration(indices: newIndices, exerciseState: newState)
        self.genericData = loadData(newIndices)
        self.exerciseState = newState
        self.indices = newIndices
        onStateChanged()
    }
    
    /// Updates state for the same exerecise
    func setState(newState: ExerciseState) {
        self.timerDuration = computeTimerDuration(indices: indices, exerciseState: newState)
        self.exerciseState = newState
        onStateChanged()
    }
    
    /// Housekeeping after changing exercises or exercise state
    private func onStateChanged() {
        // Update repeater rep
        self.repeaterRep = nextRepeaterRep()
        // Start timer if needed
        switch currentExercise {
        case .repeater(_), .maxHang(_):
            startTimer()
        default:
            break
        }
    }
    
    /// Computes the next state of the repeater rep field
    private func nextRepeaterRep() -> RepeaterRep {
        switch currentExercise {
        case .repeater(let d):
            switch exerciseState {
            case .ready:
                return .init(max: d.expected.sets[indices!.exerciseSetIndex].numReps)
            case .on:
                return repeaterRep.next()
            case .off:
                return repeaterRep
            default:
                break
            }
        default:
            break
        }
        return .zero
    }
    
    func prev() {
        stopAndResetTimer()
        if let newState = prevState() {
            setState(newState: newState)
        } else {
            setState(newIndices: prevIndices)
        }
    }
    
    func prevState() -> ExerciseState? {
        switch exerciseState {
        case .rest:
            return .ready
        default:
            return nil
        }
    }
    
    var prevIndices: ExerciseIndices? {
        if let indices {
            // Moving to new exercise set, exercise, or routine set
            // Next exercise is determined by set order
            let set = session.sets[indices.routineSetIndex]
            switch set.order {
            case .bfs:
                return getPrevBfs(indices)
            case .dfs:
                return getPrevDfs(indices)
            }
        } else {
            // Can't go backward from start
            return nil
        }
    }
    
    func next(skip: Bool = false) {
        stopAndResetTimer()
        if let newState = nextState() {
            setState(newState: newState)
        } else {
            setState(newIndices: nextIndices())
        }
    }
    
    func nextState() -> ExerciseState? {
        switch currentExercise {
        case .generic(_):
            switch exerciseState {
            case .ready, .on, .off:
                return .rest
            case .rest, nil:
                return nil
            }
        case .repeater(_):
            switch exerciseState {
            case .ready:
                return .on
            case .on:
                return repeaterRep.hasNext ? .off : .rest
            case .off:
                return .on
            case .rest, nil:
                return nil
            }
        case .maxHang(_):
            switch exerciseState {
            case .ready:
                return .on
            case .on, .off:
                return .rest
            case .rest, nil:
                return nil
            }
        case nil:
            return nil
        }
    }
    
    func nextIndices() -> ExerciseIndices? {
        if let indices {
            // Moving to new exercise set, exercise, or routine set
            // Next exercise is determined by set order
            let set = session.sets[indices.routineSetIndex]
            switch set.order {
            case .bfs:
                return getNextBfs(indices)
            case .dfs:
                return getNextDfs(indices)
            }
        } else {
            // Start at beginning
            return .init()
        }
    }
    
    func getPrevBfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let set = session.sets[indices.routineSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check behind
        for i in (0..<indices.setExerciseIndex).reversed() {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        targetIndex -= 1
        if targetIndex < 0 {
            // Exit early if impossible
            return nil
        }
        // Then loop back around to 0 for the next set
        for i in (0..<set.exercises.count).reversed() {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        // Start screen
        return nil
    }
    
    func getNextBfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let set = session.sets[indices.routineSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check ahead
        for i in (indices.setExerciseIndex + 1)..<set.exercises.count {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        targetIndex += 1
        // Then loop back around from 0 for the next set
        for i in 0..<set.exercises.count {
            if targetIndex < set.exercises[i].numSets {
                return .init(indices.routineSetIndex, i, targetIndex)
            }
        }
        // No other exercises go this high
        if indices.routineSetIndex < session.sets.count - 1 {
            // Move to next routine set
            return .init(indices.routineSetIndex + 1)
        }
        // Finish screen
        return nil
    }
    
    func getPrevDfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        if indices.exerciseSetIndex > 0 {
            // Prev set within the exercise
            return .init(indices.routineSetIndex, indices.setExerciseIndex, indices.exerciseSetIndex - 1)
        } else if indices.setExerciseIndex > 0 {
            // Next exercise within the routine set
            return .init(indices.routineSetIndex, indices.setExerciseIndex - 1)
        } else if indices.routineSetIndex > 0 {
            // Next set wtihin the routine
            return .init(indices.routineSetIndex - 1)
        } else {
            // Finish screen
            return nil
        }
    }
    
    func getNextDfs(_ indices: ExerciseIndices) -> ExerciseIndices? {
        let set = session.sets[indices.routineSetIndex]
        let exercise = set.exercises[indices.setExerciseIndex]
        if indices.exerciseSetIndex < exercise.numSets - 1 {
            // Next set within the exercise
            return .init(indices.routineSetIndex, indices.setExerciseIndex, indices.exerciseSetIndex + 1)
        } else if indices.setExerciseIndex < set.exercises.count - 1 {
            // Next exercise within the routine set
            return .init(indices.routineSetIndex, indices.setExerciseIndex + 1)
        } else if indices.routineSetIndex < session.sets.count - 1 {
            // Next set wtihin the routine
            return .init(indices.routineSetIndex + 1)
        } else {
            // Finish screen
            return nil
        }
    }
    
    
    // *************** //
    // TIMER FUNCTIONS //
    // *************** //
    
    private func toggleTimer() {
        isTimerValid ? pauseTimer() : startTimer()
    }
    
    private func startTimer() {
        guard timerDuration > .zero else { return }
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
                                // Reset timer and move to next state
                                stopAndResetTimer()
                                next()
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

    private func shouldShowCancelButton() -> Bool {
        return isTimerValid || elapsedSeconds > .seconds(0)
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
    }
    
    private func stopAndResetTimer() {
        pauseTimer()
        elapsedMilliseconds = 0
        withAnimation(.easeInOut) {
            elapsedSeconds = .zero
        }
    }
    
    private func computeTimerDuration(indices: ExerciseIndices?, exerciseState: ExerciseState?) -> Duration {
        guard let indices else { return .zero }
        let set = session.sets[indices.routineSetIndex]
        let exercise = set.exercises[indices.setExerciseIndex]
        switch exercise {
        case .repeater(let d):
            switch exerciseState {
            case .ready:
                return readyTime
            case .on:
                return .seconds(d.expected.timeOn)
            case .off:
                return .seconds(d.expected.timeOff)
            case .rest, .none:
                return .seconds(set.restTime)
            }
        case .maxHang(let d):
            switch exerciseState {
            case .ready:
                return readyTime
            case .on:
                return .seconds(d.expected.sets[indices.exerciseSetIndex].target)
            case .rest, .off, .none:
                return .seconds(set.restTime)
            }
        default:
            return .seconds(set.restTime)
        }
    }
    
    struct ExerciseIndices: Codable, Hashable, Equatable {
        var routineSetIndex: Int
        var setExerciseIndex: Int
        var exerciseSetIndex: Int
        
        init(_ routineSetIndex: Int = 0, _ setExerciseIndex: Int = 0, _ exerciseSetIndex: Int = 0) {
            self.routineSetIndex = routineSetIndex
            self.setExerciseIndex = setExerciseIndex
            self.exerciseSetIndex = exerciseSetIndex
        }
    }
    
    struct GenericDataSet: Codable, Hashable, Equatable {
        var side: Routine.Side
        var numLeft: Int
        var numRight: Int
        var weightLeft: Double
        var weightRight: Double
        var notes: String
        
        init(_ data: Session.GenericDataSet, format: Routine.GenericSets) {
            switch format.dataType {
            case .rep, .repWeight:
                self.init(numLeft: data.repsLeft, numRight: data.repsRight, weightLeft: data.weightLeft, weightRight: data.weightRight, notes: data.notes)
            case .time, .timeWeight:
                self.init(numLeft: data.timeLeft, numRight: data.timeRight, weightLeft: data.weightLeft, weightRight: data.weightRight, notes: data.notes)
            }
        }
        
        init(_ data: Session.RepeaterSet) {
            self.init(numLeft: data.numReps, weightLeft: data.weight, notes: data.notes)
        }
        
        init(_ data: Session.MaxHangSet) {
            self.init(side: data.side, numLeft: data.target, weightLeft: data.weight, notes: data.notes)
        }
        
        init(side: Routine.Side? = nil, numLeft: Int? = nil, numRight: Int? = nil, weightLeft: Double? = nil, weightRight: Double? = nil, notes: String = "") {
            self.side = side ?? .both
            self.numLeft = numLeft ?? 0
            self.numRight = numRight ?? numLeft ?? 0
            self.weightLeft = weightLeft ?? 0
            self.weightRight = weightRight ?? weightLeft ?? 0
            self.notes = notes
        }
        
        func toGeneric(_ data: Routine.GenericSets, useAlt: Bool) -> Session.GenericDataSet {
            switch data.dataType {
            case .rep:
                if data.sideType == .independent && useAlt && numLeft != numRight {
                    return .init(numReps: numLeft, numRepsAlt: numRight, notes: notes)
                }
                return .init(numReps: numLeft, notes: notes)
            case .repWeight:
                if data.sideType == .independent && useAlt {
                    var dataSet = Session.GenericDataSet(notes: notes)
                    if numLeft != numRight {
                        dataSet.numReps = numLeft
                        dataSet.numRepsAlt = numRight
                    } else {
                        dataSet.numReps = numLeft
                    }
                    if weightLeft != weightRight {
                        dataSet.weight = weightLeft
                        dataSet.weightAlt = weightRight
                    } else {
                        dataSet.weight = weightLeft
                    }
                    return dataSet
                }
                return .init(numReps: numLeft, weight: weightLeft, notes: notes)
            case .time:
                if data.sideType == .independent && useAlt && numLeft != numRight {
                    return .init(time: numLeft, timeAlt: numRight, notes: notes)
                }
                return .init(time: numLeft, notes: notes)
            case .timeWeight:
                if data.sideType == .independent && useAlt {
                    var dataSet = Session.GenericDataSet(notes: notes)
                    if numLeft != numRight {
                        dataSet.time = numLeft
                        dataSet.timeAlt = numRight
                    } else {
                        dataSet.time = numLeft
                    }
                    if weightLeft != weightRight {
                        dataSet.weight = weightLeft
                        dataSet.weightAlt = weightRight
                    } else {
                        dataSet.weight = weightLeft
                    }
                    return dataSet
                }
                return .init(time: numLeft, weight: weightLeft, notes: notes)
            }
        }
        
        func toRepeater() -> Session.RepeaterSet {
            return .init(numReps: numLeft, weight: weightLeft, notes: notes)
        }
        
        func toMaxHang() -> Session.MaxHangSet {
            return .init(side: side, target: numLeft, weight: weightLeft, notes: notes)
        }
    }
    
    enum SheetType: Identifiable, Codable, Hashable, Equatable {
        var id: String {
            switch self {
            case .date:
                "date"
            case .exercise(let setIndex, let exerciseIndex):
                "ex-\(setIndex)-\(exerciseIndex)"
            case .notes:
                "notes"
            case .song:
                "song"
            }
        }
        
        case date
        case exercise(setIndex: Int, exerciseIndex: Int)
        case notes
        case song
    }
    
    enum ExerciseState: Codable, Hashable, Equatable {
        case ready
        case on
        case off
        case rest
    }
    
    struct RepeaterRep: Codable, Hashable, Equatable {
        static let zero = RepeaterRep(max: 0)
        
        let current: Int
        let max: Int
        
        init(current: Int = 0, max: Int) {
            self.current = current
            self.max = max
        }
        
        var hasNext: Bool {
            current < max
        }
        
        func next() -> RepeaterRep {
            if hasNext {
                return .init(current: current + 1, max: max)
            }
            return self
        }
    }
}

struct RingShape: Shape {
    var progress: Double // Value from 0.0 to 1.0
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: (progress * 360) - 90)
        
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

#Preview(traits: .modifier(TestDataModifier())) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        let routine = routines.first!
        let session: Session = {
            let session = Session(startTime: .now.addingTimeInterval(-700))
            session.routine = routine
            session.sets = routine.sets.map(Session.ExerciseSet.init)
            return session
        }()
        RoutineSessionView(session: session)
    }
}

#Preview("Fresh") {
    NavigationStack {
        RoutineSessionView(session: Session())
    }
}
