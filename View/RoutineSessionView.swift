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
    
    let activeColor = Color("ActiveColor")
    let readyColor = Color("ReadyColor")
    let restColor = Color("RestColor")
    
    let readyTime: Duration = .seconds(10)
    
    var hasData: Bool {
        session.sets.contains(where: { $0.exercises.contains(where: \.hasData) })
    }
    
    @State private var session: Session
    @State private var indices: ExerciseIndices? = nil
    @State private var elapsedSeconds: Duration = .seconds(0)
    // For better interactivity precision
    @State private var elapsedMilliseconds: Int = 0
    @State private var cancellable: Cancellable?
    @State private var genericData: GenericDataSet = .init()
    @State private var showSheet: Bool = false
    @State private var editExercise: (Int, Int)? = nil
    
    var currentExercise: Session.Exercise? {
        if let indices {
            return session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        }
        return nil
    }
    
    private var timerDuration: Duration {
        guard let indices else { return .zero }
        let set = session.sets[indices.routineSetIndex]
        let exercise = set.exercises[indices.setExerciseIndex]
        switch exercise {
        case .repeater(let d):
            guard case .repeater(let s, _) = indices.details else { return .zero }
            switch s {
            case .ready:
                return readyTime
            case .on:
                return .seconds(d.expected.timeOn)
            case .off:
                return .seconds(d.expected.timeOff)
            case .done:
                return .seconds(set.restTime)
            }
        case .maxHang(let d):
            guard case .maxHang(let s) = indices.details else { return .zero }
            switch s {
            case .ready:
                return readyTime
            case .on:
                return .seconds(d.expected.sets[indices.exerciseSetIndex].target)
            case .done:
                return .seconds(set.restTime)
            }
        default:
            return .seconds(set.restTime)
        }
    }
    
    init(session: Session) {
        self.session = session
    }
    
    var body: some View {
        mainView()
            .navigationTitle("Session Overview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .background(computeBackground())
            .sheet(isPresented: $showSheet) {
                Form {
                    TextField("Notes", text: $genericData.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }.presentationDetents([.medium, .large])
            }
            .sheet(isPresented: .init(get: {
                editExercise != nil
            }, set: { newValue in
                if !newValue {
                    editExercise = nil
                }
            })) {
                if let editExercise {
                    SessionExerciseSheet(exercise: .init(get: {
                        session.sets[editExercise.0].exercises[editExercise.1]
                    }, set: { newValue in
                        session.sets[editExercise.0].exercises[editExercise.1] = newValue
                    }))
                } else {
                    Text("TODO FIX ME")
                }
            }
            .toolbar(content: buildToolbar)
    }
    
    @ToolbarContentBuilder
    func buildToolbar() -> some ToolbarContent {
        if indices == nil {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    if session.endTime == nil {
                        Button {
                            session.endTime = .now
                        } label: {
                            Label("Finish Session", systemImage: "checkmark")
                        }
                    } else {
                        Button {
                            session.endTime = nil
                        } label: {
                            Label("Re-open Session", systemImage: "play")
                        }
                    }
                    
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    next()
                } label: {
                    Label("Start", systemImage: "play")
                }
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if indices != nil {
                    indices = nil
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
    
    func computeBackground() -> some ShapeStyle {
        if let indices {
            switch indices.details {
            case .generic:
                return restColor
            case .repeater(let s, _):
                switch s {
                case .ready:
                    return readyColor
                case .on:
                    return activeColor
                case .off:
                    return readyColor
                case .done:
                    return restColor
                }
            case .maxHang(let s):
                switch s {
                case .ready:
                    return readyColor
                case .on:
                    return activeColor
                case .done:
                    return restColor
                }
            }
        }
        return Color(uiColor: .systemGroupedBackground)
    }
    
    @ViewBuilder
    func mainView() -> some View {
        if let indices {
            switch indices.details {
            case .generic:
                genericExerciseView()
            case .repeater(let s, let rep):
                repeaterExerciseView(s, rep)
            case .maxHang(let s):
                maxHangExerciseView(s)
            }
        } else {
            landingPage()
        }
    }
    
    @ViewBuilder
    func landingPage() -> some View {
        Form {
            Section {
                DatePicker("Start:", selection: $session.startTime, displayedComponents: [.date, .hourAndMinute])
                if session.endTime == nil && hasData {
                    Button {
                        session.endTime = .now
                        dismiss()
                    } label: {
                        Label("Finish Session", systemImage: "checkmark")
                    }
                } else if hasData {
                    DatePicker("End:", selection: .init(get: {
                        session.endTime ?? .now
                    }, set: { newValue in
                        session.endTime = newValue
                    }), displayedComponents: [.date, .hourAndMinute])
                }
                TextField("Notes", text: $session.notes, axis: .vertical)
                    .lineLimit(3...9)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
            } header: {
                if let routine = session.routine {
                    Text(routine.name)
                }
            }
            ForEach(session.sets.enumerated(), id: \.offset) { offset, set in
                let setIndex = offset
                Section {
                    ForEach(set.exercises.enumerated(), id: \.offset) { offset, exercise in
                        let exerciseIndex = offset
                        Menu {
                            Button {
                                // Make sure timer is reset
                                stopAndResetTimer()
                                // Go to exercise
                                updateIndices(routineSetIndex: setIndex, setExerciseIndex: exerciseIndex, exerciseSetIndex: 0)
                            } label: {
                                Label("Start Exercise", systemImage: "play")
                            }
                            Button {
                                editExercise = (setIndex, exerciseIndex)
                            } label: {
                                Label("Edit Exercise", systemImage: "pencil")
                            }
                        } label: {
                            HStack {
                                SessionExerciseEntryView(exercise: exercise)
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text(set.name)
                        Spacer()
                        Text("\(set.restTime)s Rest")
                    }
                }
            }
        }
    }
    
    func updateIndices(routineSetIndex: Int, setExerciseIndex: Int, exerciseSetIndex: Int) {
        let set = session.sets[routineSetIndex]
        let exercise = set.exercises[setExerciseIndex]
        switch exercise {
        case .generic(let d):
            genericData = .init(num: d.expected.sets[exerciseSetIndex].avg)
            indices = .init(routineSetIndex: routineSetIndex, setExerciseIndex: setExerciseIndex, exerciseSetIndex: exerciseSetIndex, details: .generic)
        case .repeater(let d):
            let expected = d.expected.sets[exerciseSetIndex]
            genericData = .init(num: expected.numReps, weight: expected.weight)
            indices = .init(routineSetIndex: routineSetIndex, setExerciseIndex: setExerciseIndex, exerciseSetIndex: exerciseSetIndex, details: .repeater(.ready, reps: d.expected.sets[exerciseSetIndex].numReps))
        case .maxHang(let d):
            let expected = d.expected.sets[exerciseSetIndex]
            genericData = .init(side: expected.side, num: expected.target, weight: expected.weight)
            indices = .init(routineSetIndex: routineSetIndex, setExerciseIndex: setExerciseIndex, exerciseSetIndex: exerciseSetIndex, details: .maxHang(.ready))
        }
    }
    
    func saveData(_ indices: ExerciseIndices) {
        let exercise = session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            var newActual: [Session.GenericDataSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = genericData.toGeneric(d.expected.dataType)
            } else {
                newActual.append(genericData.toGeneric(d.expected.dataType))
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
    
    func prev() {
        if let indices {
            // Stop timer first in all cases
            stopAndResetTimer()
            if let newIndices = tryPrevExercise(indices) {
                // Stay on current exercise set, moving to new state
                self.indices = newIndices
            } else {
                // Moving to new exercise set, exercise, or routine set
                // Next exercise is determined by set order
                let set = session.sets[indices.routineSetIndex]
                switch set.order {
                case .bfs:
                    prevBfs(indices)
                case .dfs:
                    prevDfs(indices)
                }
            }
        }
    }
    
    func next(skip: Bool = false) {
        if let indices {
            if !skip, let newIndices = tryNextExercise(indices) {
                // Stay on current exercise set, moving to new state
                self.indices = newIndices
                // Currently, all internal states should auto-start timer
                startTimer()
            } else {
                // Moving to new exercise set, exercise, or routine set
                // Stop timer in all cases
                stopAndResetTimer()
                // Next exercise is determined by set order
                let set = session.sets[indices.routineSetIndex]
                switch set.order {
                case .bfs:
                    nextBfs(indices)
                case .dfs:
                    nextDfs(indices)
                }
            }
        } else {
            // Start at beginning
            updateIndices(routineSetIndex: 0, setExerciseIndex: 0, exerciseSetIndex: 0)
        }
    }
    
    func prevBfs(_ indices: ExerciseIndices) {
        let set = session.sets[indices.routineSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check behind
        for i in (0..<indices.setExerciseIndex).reversed() {
            if targetIndex < set.exercises[i].numSets {
                updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: i, exerciseSetIndex: targetIndex)
                return
            }
        }
        targetIndex -= 1
        if targetIndex < 0 {
            // Exit early if impossible
            self.indices = nil
            return
        }
        // Then loop back around to 0 for the next set
        for i in (0..<set.exercises.count).reversed() {
            if targetIndex < set.exercises[i].numSets {
                updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: i, exerciseSetIndex: targetIndex)
                return
            }
        }
        // Finish screen
        self.indices = nil
    }
    
    func nextBfs(_ indices: ExerciseIndices) {
        let set = session.sets[indices.routineSetIndex]
        var targetIndex = indices.exerciseSetIndex
        // First check ahead
        for i in (indices.setExerciseIndex + 1)..<set.exercises.count {
            if targetIndex < set.exercises[i].numSets {
                updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: i, exerciseSetIndex: targetIndex)
                return
            }
        }
        targetIndex += 1
        // Then loop back around from 0 for the next set
        for i in 0..<set.exercises.count {
            if targetIndex < set.exercises[i].numSets {
                updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: i, exerciseSetIndex: targetIndex)
                return
            }
        }
        // No other exercises go this high
        if indices.routineSetIndex < session.sets.count - 1 {
            // Move to next routine set
            updateIndices(routineSetIndex: indices.routineSetIndex + 1, setExerciseIndex: 0, exerciseSetIndex: 0)
        } else {
            // Finish screen
            self.indices = nil
        }
    }
    
    func prevDfs(_ indices: ExerciseIndices) {
        if indices.exerciseSetIndex > 0 {
            // Prev set within the exercise
            updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: indices.setExerciseIndex, exerciseSetIndex: indices.exerciseSetIndex - 1)
        } else if indices.setExerciseIndex > 0 {
            // Next exercise within the routine set
            updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: indices.setExerciseIndex - 1, exerciseSetIndex: 0)
        } else if indices.routineSetIndex > 0 {
            // Next set wtihin the routine
            updateIndices(routineSetIndex: indices.routineSetIndex - 1, setExerciseIndex: 0, exerciseSetIndex: 0)
        } else {
            // Finish screen
            self.indices = nil
        }
    }
    
    func nextDfs(_ indices: ExerciseIndices) {
        let set = session.sets[indices.routineSetIndex]
        let exercise = set.exercises[indices.setExerciseIndex]
        if indices.exerciseSetIndex < exercise.numSets - 1 {
            // Next set within the exercise
            updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: indices.setExerciseIndex, exerciseSetIndex: indices.exerciseSetIndex + 1)
        } else if indices.setExerciseIndex < set.exercises.count - 1 {
            // Next exercise within the routine set
            updateIndices(routineSetIndex: indices.routineSetIndex, setExerciseIndex: indices.setExerciseIndex + 1, exerciseSetIndex: 0)
        } else if indices.routineSetIndex < session.sets.count - 1 {
            // Next set wtihin the routine
            updateIndices(routineSetIndex: indices.routineSetIndex + 1, setExerciseIndex: 0, exerciseSetIndex: 0)
        } else {
            // Finish screen
            self.indices = nil
        }
    }
    
    func tryPrevExercise(_ indices: ExerciseIndices) -> ExerciseIndices? {
        switch indices.details {
        case .generic:
            return nil
        case .repeater(let s, _):
            switch s {
            case .ready:
                return nil
            default:
                if case .repeater(let d) = currentExercise {
                    return .init(baseIndices: indices, details: .repeater(.ready, reps: d.expected.sets[indices.exerciseSetIndex].numReps))
                } else {
                    return nil
                }
            }
        case .maxHang(let s):
            switch s {
            case .ready:
                return nil
            default:
                return .init(baseIndices: indices, details: .maxHang(.ready))
            }
        }
    }
    
    func tryNextExercise(_ indices: ExerciseIndices) -> ExerciseIndices? {
        switch indices.details {
        case .generic:
            return nil
        case .repeater(let s, let reps):
            switch s {
            case .ready:
                return .init(baseIndices: indices, details: .repeater(.on, reps: reps))
            case .on:
                if reps > 1 {
                    return .init(baseIndices: indices, details: .repeater(.off, reps: reps - 1))
                } else {
                    return .init(baseIndices: indices, details: .repeater(.done, reps: 0))
                }
            case .off:
                return .init(baseIndices: indices, details: .repeater(.on, reps: reps))
            case .done:
                return nil
            }
        case .maxHang(let s):
            switch s {
            case .ready:
                return .init(baseIndices: indices, details: .maxHang(.on))
            case .on:
                return .init(baseIndices: indices, details: .maxHang(.done))
            case .done:
                return nil
            }
        }
    }
    
    @ViewBuilder
    func genericExerciseView() -> some View {
        restAndRecordView()
    }
    
    @ViewBuilder
    func repeaterExerciseView(_ state: RepeaterState, _ rep: Int) -> some View {
        let text: String = {
            switch state {
            case .ready:
                return "Get Ready"
            case .on:
                return "On"
            case .off:
                return "Off"
            case .done:
                return "Rest"
            }
        }()
        let setIndex = indices!.exerciseSetIndex
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
                    Text("\(numReps - rep + (state != .on ? 0 : 1))/\(numReps)")
                }.font(.system(size: 30))
                    .fontWeight(.semibold)
            } else {
                Text(currentExercise?.description ?? "???")
                    .font(.title)
                    .bold()
            }
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
            }.padding()
            if state == .done {
                VStack {
                    HStack {
                        Stepper(value: $genericData.num, in: 0...100) {
                            Text("\(genericData.num) reps")
                        }
                        Spacer()
                        Stepper(value: $genericData.weight, in: -200...200, step: 5) {
                            HStack {
                                TextField("", value: $genericData.weight, format: .number.precision(.fractionLength(0...2)))
                                    .keyboardType(.decimalPad)
                                Text("lbs")
                            }
                        }
                    }.font(.title2)
                        .bold()
                    Button {
                        showSheet = true
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
            } else {
                Button {
                    if let indices {
                        self.indices = .init(routineSetIndex: indices.routineSetIndex, setExerciseIndex: indices.setExerciseIndex, exerciseSetIndex: indices.exerciseSetIndex, details: .repeater(.done, reps: 0))
                    }
                } label: {
                    Text("Record Data")
                }
            }
            Spacer()
            controlView()
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func maxHangExerciseView(_ state: MaxHangState) -> some View {
        switch state {
        case .ready:
            timerView("Get Ready")
        case .on:
            timerView("On")
        case .done:
            restAndRecordView()
        }
    }
    
    @ViewBuilder
    func timerView(_ str: String) -> some View {
        VStack(alignment: .center) {
            Spacer()
            Text(currentExercise!.description)
                .font(.title)
                .bold()
            ZStack {
                RingShape(progress: 1.0)
                    .stroke(.secondary, lineWidth: 8)
                RingShape(progress: 1.0 - progress)
                    .stroke(.primary, style: .init(lineWidth: 12, lineCap: .round))
                VStack(spacing: 0) {
                    Text(str)
                        .font(.system(size: 40))
                        .bold()
                    Text(timerDuration - elapsedSeconds, format: .time(pattern: .minuteSecond(padMinuteToLength: 2)))
                        .contentTransition(.numericText())
                        .monospaced()
                        .font(.system(size: 60))
                        .bold()
                }
            }.padding()
            Spacer()
            controlView()
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func restAndRecordView() -> some View {
        VStack(alignment: .center) {
            Text(currentExercise!.getDescription(setIndex: indices!.exerciseSetIndex))
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
                Stepper(value: $genericData.num, in: 0...100) {
                    Text("\(genericData.num) \(d.expected.setDetailText)")
                }
                switch d.expected.dataType {
                case .repWeight, .timeWeight:
                    Stepper(value: $genericData.weight, in: -200...200, step: 5) {
                        HStack {
                            TextField("", value: $genericData.weight, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }
                default:
                    EmptyView()
                }
                Button {
                    showSheet = true
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
                Stepper(value: $genericData.num, in: 0...100) {
                    Text("\(genericData.num) reps")
                }
                Stepper(value: $genericData.weight, in: -200...200, step: 5) {
                    HStack {
                        TextField("", value: $genericData.weight, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                        Text("lbs")
                    }
                }
                Button {
                    showSheet = true
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
                Stepper(value: $genericData.num, in: 0...30) {
                    Text("\(genericData.num) seconds")
                }
                Stepper(value: $genericData.weight, in: -200...200, step: 5) {
                    HStack {
                        TextField("", value: $genericData.weight, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                        Text("lbs")
                    }
                }
                Button {
                    showSheet = true
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
            }
            Button {
                stopAndResetTimer()
                next(skip: true)
            } label: {
                Image(systemName: "arrowshape.forward.circle")
                    .font(.system(size: 64))
            }
            Spacer()
        }.buttonStyle(.plain)
    }
    
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
                            stopAndResetTimer()
                            next()
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
    
    struct ExerciseIndices: Codable, Hashable, Equatable {
        var routineSetIndex: Int
        var setExerciseIndex: Int
        var exerciseSetIndex: Int
        var details: ExerciseDetails
        
        init(routineSetIndex: Int, setExerciseIndex: Int, exerciseSetIndex: Int, details: ExerciseDetails) {
            self.routineSetIndex = routineSetIndex
            self.setExerciseIndex = setExerciseIndex
            self.exerciseSetIndex = exerciseSetIndex
            self.details = details
        }
        
        init(baseIndices: ExerciseIndices, details: ExerciseDetails) {
            self.routineSetIndex = baseIndices.routineSetIndex
            self.setExerciseIndex = baseIndices.setExerciseIndex
            self.exerciseSetIndex = baseIndices.exerciseSetIndex
            self.details = details
        }
    }
    
    struct GenericDataSet: Codable, Hashable, Equatable {
        var side: Routine.Side
        var num: Int
        var weight: Double
        var notes: String
        
        init(_ data: Session.GenericDataSet, type: Routine.GenericSets.DataType) {
            switch type {
            case .rep, .repWeight:
                self.init(num: data.numReps ?? 1, weight: data.weight ?? 0, notes: data.notes)
            case .time, .timeWeight:
                self.init(num: data.time ?? 1, weight: data.weight ?? 0, notes: data.notes)
            }
        }
        
        init(_ data: Session.RepeaterSet) {
            self.init(num: data.numReps, weight: data.weight, notes: data.notes)
        }
        
        init(_ data: Session.MaxHangSet) {
            self.init(side: data.side, num: data.target, weight: data.weight, notes: data.notes)
        }
        
        init(side: Routine.Side = .both, num: Int = 1, weight: Double = 0.0, notes: String = "") {
            self.side = side
            self.num = num
            self.weight = weight
            self.notes = notes
        }
        
        func toGeneric(_ type: Routine.GenericSets.DataType) -> Session.GenericDataSet {
            switch type {
            case .rep:
                return .init(numReps: num, notes: notes)
            case .repWeight:
                return .init(numReps: num, weight: weight, notes: notes)
            case .time:
                return .init(time: num, notes: notes)
            case .timeWeight:
                return .init(time: num, weight: weight, notes: notes)
            }
        }
        
        func toRepeater() -> Session.RepeaterSet {
            return .init(numReps: num, weight: weight, notes: notes)
        }
        
        func toMaxHang() -> Session.MaxHangSet {
            return .init(side: side, target: num, weight: weight, notes: notes)
        }
    }
    
    enum ExerciseDetails: Codable, Hashable, Equatable {
        case generic
        case repeater(_ state: RepeaterState, reps: Int)
        case maxHang(_ state: MaxHangState)
    }
    
    enum RepeaterState: Codable, Hashable, Equatable {
        case ready, on, off, done
    }
    
    enum MaxHangState: Codable, Hashable, Equatable {
        case ready, on, done
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
            let session = Session()
            session.routine = routine
            session.sets = routine.sets.map(Session.ExerciseSet.init)
            return session
        }()
        RoutineSessionView(session: session)
    }
}
