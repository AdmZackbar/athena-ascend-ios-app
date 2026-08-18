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
    
    let readyTime: Duration = .seconds(3)
    
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
    @State private var repeaterData: Session.RepeaterSet = .init()
    @State private var maxHangData: Session.MaxHangSet = .init(side: .left)
    
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
            .navigationTitle(session.routine?.name ?? "Session \(session.startTime.formatted(date: .abbreviated, time: .omitted))")
            .navigationBarTitleDisplayMode(indices == nil ? .automatic : .inline)
            .navigationBarBackButtonHidden()
            .background(computeBackground())
            .toolbar {
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
            // TODO distinguish between start and end
            landingPage()
        }
    }
    
    @ViewBuilder
    func landingPage() -> some View {
        if !session.sets.isEmpty {
            VStack {
                Form {
                    ForEach(session.sets.enumerated(), id: \.offset) { offset, set in
                        let setIndex = offset
                        Section("Set \(setIndex + 1)/\(session.sets.count): \(set.name)") {
                            ForEach(set.exercises.enumerated(), id: \.offset) { offset, exercise in
                                let exerciseIndex = offset
                                Button {
                                    updateIndices(routineSetIndex: setIndex, setExerciseIndex: exerciseIndex, exerciseSetIndex: 0)
                                } label: {
                                    exerciseEntryView(exercise)
                                }
                            }
                        }
                    }
                }
                Button("Start") {
                    next()
                }
            }
        } else {
            Text("No Sets!")
        }
    }
    
    @ViewBuilder
    func exerciseEntryView(_ exercise: Session.Exercise) -> some View {
        switch exercise {
        case .generic(let d):
            if d.actual.isEmpty {
                Text(exercise.description)
            } else {
                VStack(alignment: .leading) {
                    Text(exercise.description)
                    ForEach(d.actual.enumerated(), id: \.offset) { offset, set in
                        Text(set.text)
                            .font(.subheadline)
                    }
                }
            }
        case .repeater(let d):
            if d.actual.isEmpty {
                Text(exercise.description)
            } else {
                VStack(alignment: .leading) {
                    Text(exercise.description)
                    ForEach(d.actual.enumerated(), id: \.offset) { offset, set in
                        Text(set.text)
                            .font(.subheadline)
                    }
                }
            }
        case .maxHang(let d):
            if d.actual.isEmpty {
                Text(exercise.description)
            } else {
                VStack(alignment: .leading) {
                    Text(exercise.description)
                    ForEach(d.actual.enumerated(), id: \.offset) { offset, set in
                        Text(set.text)
                            .font(.subheadline)
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
            repeaterData = .init(numReps: expected.numReps, weight: expected.weight)
            indices = .init(routineSetIndex: routineSetIndex, setExerciseIndex: setExerciseIndex, exerciseSetIndex: exerciseSetIndex, details: .repeater(.ready, reps: d.expected.sets[exerciseSetIndex].numReps))
        case .maxHang(let d):
            let expected = d.expected.sets[exerciseSetIndex]
            maxHangData = .init(side: expected.side, target: expected.target, weight: expected.weight)
            indices = .init(routineSetIndex: routineSetIndex, setExerciseIndex: setExerciseIndex, exerciseSetIndex: exerciseSetIndex, details: .maxHang(.ready))
        }
    }
    
    func saveData(_ indices: ExerciseIndices) {
        let exercise = session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex]
        switch exercise {
        case .generic(let d):
            var newActual: [Session.GenericDataSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = genericData.toSessionData(d.expected.dataType)
            } else {
                newActual.append(genericData.toSessionData(d.expected.dataType))
            }
            session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .generic(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .repeater(let d):
            var newActual: [Session.RepeaterSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = repeaterData
            } else {
                newActual.append(repeaterData)
            }
            session.sets[indices.routineSetIndex].exercises[indices.setExerciseIndex] = .repeater(.init(expected: d.expected, actual: newActual, notes: d.notes))
        case .maxHang(let d):
            var newActual: [Session.MaxHangSet] = d.actual
            if indices.exerciseSetIndex < d.actual.count {
                newActual[indices.exerciseSetIndex] = maxHangData
            } else {
                newActual.append(maxHangData)
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
                stopAndResetTimer()
                // Save recorded data
                saveData(indices)
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
        case .repeater(let s, let reps):
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
        VStack(alignment: .center) {
            Spacer()
            if case .repeater(let d) = currentExercise {
                let numReps = d.expected.sets[setIndex].numReps
                HStack {
                    Text(d.expected.tag)
                        .font(.system(size: 40))
                        .bold()
                    Spacer()
                }
                HStack {
                    Text("\(d.expected.timeOn)s/\(d.expected.timeOff)s")
                    Spacer()
                    Text("\(d.expected.sets[setIndex].weight.lbsFormat)")
                }.font(.system(size: 32))
                    .fontWeight(.semibold)
                HStack {
                    Text("Rep:")
                    Spacer()
                    Text("\(numReps - rep + (state != .on ? 0 : 1))/\(numReps)")
                }.font(.title2)
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
                        Stepper(value: $repeaterData.numReps, in: 0...100) {
                            Text("\(repeaterData.numReps) reps")
                        }
                        Spacer()
                        Stepper(value: $repeaterData.weight, in: -200...200, step: 5) {
                            HStack {
                                TextField("", value: $repeaterData.weight, format: .number.precision(.fractionLength(0...2)))
                                    .keyboardType(.decimalPad)
                                Text("lbs")
                            }
                        }
                    }.font(.title2)
                        .bold()
                    TextField("Notes", text: $repeaterData.notes, axis: .vertical)
                        .font(.headline)
                        .lineLimit(2)
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
                TextField("Notes", text: $genericData.notes, axis: .vertical)
                    .font(.headline)
                    .lineLimit(2)
            }
        case .repeater(_):
            VStack {
                Stepper(value: $repeaterData.numReps, in: 0...100) {
                    Text("\(repeaterData.numReps) reps")
                }
                Stepper(value: $repeaterData.weight, in: -200...200, step: 5) {
                    HStack {
                        TextField("", value: $repeaterData.weight, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                        Text("lbs")
                    }
                }
                TextField("Notes", text: $repeaterData.notes, axis: .vertical)
                    .font(.headline)
                    .lineLimit(2)
            }
        case .maxHang(_):
            VStack {
                Stepper(value: $maxHangData.target, in: 0...30) {
                    Text("\(maxHangData.target) seconds")
                }
                Stepper(value: $maxHangData.weight, in: -200...200, step: 5) {
                    HStack {
                        TextField("", value: $maxHangData.weight, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                        Text("lbs")
                    }
                }
                TextField("Notes", text: $maxHangData.notes, axis: .vertical)
                    .font(.headline)
                    .lineLimit(2)
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
        var num: Int
        var weight: Double
        var notes: String
        
        init(num: Int = 1, weight: Double = 0.0, notes: String = "") {
            self.num = num
            self.weight = weight
            self.notes = notes
        }
        
        func toSessionData(_ type: Routine.GenericSets.DataType) -> Session.GenericDataSet {
            switch type {
            case .rep:
                return .init(numReps: num)
            case .repWeight:
                return .init(numReps: num, weight: weight)
            case .time:
                return .init(time: num)
            case .timeWeight:
                return .init(weight: weight, time: num)
            }
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
