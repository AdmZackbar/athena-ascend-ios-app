//
//  SessionLiveView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/28/26.
//

import SwiftData
import SwiftUI
internal import Combine

/// Allows the user to progress a `Session` through each super set, exercise, and set.
struct SessionLiveView: View {
    @Environment(\.dismiss) var dismiss
    
    let session: Session
    
    @State private var state: ViewState
    // Timer vars
    /// Set to the start time of the timer (in seconds)
    var timerDuration: Duration {
        .seconds(state.maxTimeSeconds)
    }
    /// Tracks how many seconds have passed for the current timer
    @State private var elapsedSeconds: Duration = .zero
    /// For better interactivity precision
    @State private var elapsedMilliseconds: Int = 0
    /// The absolute end date of the current timer, if running. Lets the watch render a live
    /// countdown without any per-second WatchConnectivity traffic.
    @State private var timerEndDate: Date? = nil
    /// The current timer, if in use
    @State private var cancellable: Cancellable?
    /// If false, disallows the timer from advancing state after the record/rest period ends
    @State private var timerNextOverride: Bool = false
    /// If true, the timer is allowed to modify the state when it finishes
    var allowTimerNext: Bool {
        return state.exerciseState != .record || timerNextOverride
    }
    
    init(sessionData: ExerciseData) {
        self.session = sessionData.session
        self.state = .init(data: sessionData, setIndex: 0)
    }
    
    var body: some View {
        mainView()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(background)
    }
    
    var title: String {
        return session.superSets[state.superSetIndex].name
    }
    
    /// The background color of the view
    var background: some ShapeStyle {
        switch state.exerciseState {
        case .ready, .rest:
            return .ready
        case .active:
            return .active
        case .record:
            if timerDuration > .zero && progress <= 0.25 {
                return .rest.mix(with: .ready, by: 1.0 - (progress * 4.0), in: .perceptual)
            }
            return .rest
        }
    }
    
    @ViewBuilder
    func mainView() -> some View {
        VStack {
            headerView(state)
            Spacer()
            timerView(state)
            controlView()
        }.padding([.leading, .trailing])
    }
    
    @ViewBuilder
    func headerView(_ state: ViewState) -> some View {
        let data = state.dataSet
        let numSets = state.data.expectedData.count
        let repText = state.repState?.text
        switch state.data.exercise.category {
        case .generic(let name, _, let sideType):
            ExerciseStateView(titleLeading: name, titleTrailing: sideType == .independent ? "[L/R]" : nil, subheadline: data.getSummary(useAlt: state.repState?.hasNext ?? false), setIndex: state.setIndex, numSets: numSets, repText: repText)
        case .repeater(let tag, let timeOn, let timeOff):
            ExerciseStateView(titleLeading: tag, titleTrailing: "\(timeOn)s/\(timeOff)s", subheadline: data.getSummary(useAlt: state.repState?.hasNext ?? false), setIndex: state.setIndex, numSets: numSets, repText: repText)
        case .maxHang(let tag, let sideType):
            ExerciseStateView(titleLeading: tag, titleTrailing: sideType == .independent ? "[L/R]" : nil, subheadline: data.getSummary(useAlt: state.repState?.hasNext ?? false), setIndex: state.setIndex, numSets: numSets, repText: repText)
        case .campus(let name, let mirrorSets):
            ExerciseStateView(titleLeading: name, titleTrailing: mirrorSets ? "[L/R]" : nil, subheadline: data.getSummary(useAlt: state.repState?.hasNext ?? false), setIndex: state.setIndex, numSets: numSets, repText: repText)
        }
    }
    
    @ViewBuilder
    func timerView(_ state: ViewState) -> some View {
        // TODO other cases
        let text: String = {
            switch state.exerciseState {
            case .ready:
                return "Ready"
            case .active:
                return "On"
            case .rest:
                return "Off"
            case .record:
                return "Rest"
            }
        }()
        // TODO countdown direction
        TimerRingView(text: text, textCountDown: true, timerDuration: timerDuration, elapsedSeconds: elapsedSeconds, progress: progress)
    }
    
    @ViewBuilder
    func controlView() -> some View {
        HStack(spacing: 16) {
            Spacer()
            Button(action: prev) {
                Image(systemName: "arrowshape.backward.circle")
                    .font(.system(size: 64))
            }
            Button(action: toggleTimer) {
                Image(systemName: isTimerValid ? "pause.circle" : "play.circle")
                    .font(.system(size: 96))
            }.disabled(elapsedSeconds >= timerDuration)
            Button(action: next) {
                Image(systemName: allowTimerNext || elapsedSeconds >= timerDuration ? "arrowshape.forward.circle" : "checkmark.circle")
                    .font(.system(size: 64))
            }
            Spacer()
        }.buttonStyle(.plain)
    }
    
    // State functions
    
    func prev() {
        stopAndResetTimer()
        // First try to go back to the prev exercise state
        // Then try to move to the prev exercise
        if let prev = state.prev ?? prevExercise {
            state = prev
        }
        // Don't start timer again
    }
    
    func next() {
        guard allowTimerNext || elapsedSeconds >= timerDuration else {
            timerNextOverride = true
            return
        }
        stopAndResetTimer()
        // First try to advance to the next exercise state
        // Then try to move to the next exercise
        if let next = state.next ?? nextExercise {
            state = next
            timerNextOverride = false
            startTimer()
        } else {
            // Session is complete, exit
            dismiss()
        }
    }
    
    var prevExercise: ViewState? {
        let sortedData = session.data
            // Need to have data to go on
            .filter({ !$0.expectedData.isEmpty })
            // Sort by super set, then by exercise index DESCENDING
            .sorted(by: { $0.position > $1.position })
        // First check within the set
        switch session.superSets[state.superSetIndex].order {
        case .bfs:
            // First check behind in the prev exercise for the same set index
            if let prev = sortedData.filter({ $0.position.superSetIndex == state.superSetIndex && $0.position.setIndex < state.exerciseIndex && $0.expectedData.count > state.setIndex }).first {
                return .init(data: prev, setIndex: state.setIndex)
            }
            // Then check all if any can support the prev set index
            if state.setIndex > 0, let prev = sortedData.filter({ $0.position.superSetIndex == state.superSetIndex && $0.expectedData.count > state.setIndex - 1 }).first {
                return .init(data: prev, setIndex: state.setIndex - 1)
            }
        case .dfs:
            // First try to go back to the prev set of the same exercise
            if state.setIndex > 0 {
                return .init(data: state.data, setIndex: state.setIndex - 1)
            }
            // Then try to move to the prev exercise (first set)
            if let prev = sortedData.filter({ $0.position.superSetIndex == state.superSetIndex && $0.position.setIndex < state.exerciseIndex }).first {
                return .init(data: prev, setIndex: prev.expectedData.count - 1)
            }
        }
        // Then go to the prev super set (if it exists and has data)
        if let prev = sortedData.filter({ $0.position.superSetIndex < state.superSetIndex }).first {
            return .init(data: prev, setIndex: prev.expectedData.count - 1)
        }
        // Otherwise, nowhere to go
        return nil
    }
    
    var nextExercise: ViewState? {
        let sortedData = session.data
            // Need to have data to go on
            .filter({ !$0.expectedData.isEmpty })
            // Sort by super set, then by exercise index
            .sorted(by: { $0.position < $1.position })
        // First check within the set
        switch session.superSets[state.superSetIndex].order {
        case .bfs:
            // First check ahead in the next exercise for the same set index
            if let next = sortedData.filter({ $0.position.superSetIndex == state.superSetIndex && $0.position.setIndex > state.exerciseIndex && $0.expectedData.count > state.setIndex }).first {
                return .init(data: next, setIndex: state.setIndex)
            }
            // Then check all if any can support the next set index
            if let next = sortedData.filter({ $0.position.superSetIndex == state.superSetIndex && $0.expectedData.count > state.setIndex + 1 }).first {
                return .init(data: next, setIndex: state.setIndex + 1)
            }
        case .dfs:
            // First try to advance to the next set of the same exercise
            if state.setIndex < state.data.expectedData.count {
                return .init(data: state.data, setIndex: state.setIndex + 1)
            }
            // Then try to move to the next exercise (first set)
            if let next = sortedData.filter({ $0.position.superSetIndex == state.superSetIndex && $0.position.setIndex > state.exerciseIndex }).first {
                return .init(data: next, setIndex: 0)
            }
        }
        // Then go to the next super set (if it exists and has data)
        if let next = sortedData.filter({ $0.position.superSetIndex > state.superSetIndex }).first {
            return .init(data: next, setIndex: 0)
        }
        // Otherwise, nowhere to go
        return nil
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
    
    struct ViewState {
        var data: ExerciseData
        var setIndex: Int
        var exerciseState: ExerciseState
        var repState: RepState?
        
        init(data: ExerciseData, setIndex: Int) {
            self.data = data
            self.setIndex = setIndex
            self.exerciseState = .ready
            self.repState = initialRepState
        }
        
        private init(data: ExerciseData, setIndex: Int, exerciseState: ExerciseState, repState: RepState? = nil) {
            self.data = data
            self.setIndex = setIndex
            self.exerciseState = exerciseState
            self.repState = repState
        }
        
        var dataSet: ExerciseData.DataSet {
            return data.expectedData[setIndex]
        }
        
        var superSetIndex: Int {
            return data.position.superSetIndex
        }
        
        var exerciseIndex: Int {
            return data.position.setIndex
        }
        
        var usesActiveTimer: Bool {
            switch data.exercise.category {
            case .generic(_, let dataTypes, _):
                return dataTypes.contains(.time)
            case .repeater(_, _, _):
                return true
            case .maxHang(_, _):
                return true
            case .campus(_, _):
                return false
            }
        }
        
        var setRestTime: Int {
            data.session.superSets[superSetIndex].restTime
        }
        
        var maxTimeSeconds: Int {
            if !usesActiveTimer {
                return 0
            }
            switch data.exercise.category {
            case .generic(_, _, _):
                switch exerciseState {
                case .ready:
                    return 10
                case .active:
                    if (repState?.hasNext ?? false) {
                        return dataSet[.timeAlt]?.num ?? dataSet[.time]?.num ?? 0
                    }
                    return dataSet[.time]?.num ?? 0
                case .rest:
                    return 20
                case .record:
                    return (repState?.hasNext ?? false) ? 20 : setRestTime
                }
            case .repeater(_, let timeOn, let timeOff):
                switch exerciseState {
                case .ready:
                    return 10
                case .active:
                    return timeOn
                case .rest:
                    return timeOff
                case .record:
                    return setRestTime
                }
            case .maxHang(_, _):
                switch exerciseState {
                case .ready:
                    return 10
                case .active:
                    if (repState?.hasNext ?? false) {
                        return dataSet[.timeAlt]?.num ?? dataSet[.time]?.num ?? 0
                    }
                    return dataSet[.time]?.num ?? 0
                case .rest:
                    return 20
                case .record:
                    return (repState?.hasNext ?? false) ? 20 : setRestTime
                }
            case .campus(_, _):
                switch exerciseState {
                case .ready, .active, .rest:
                    // Timer unused
                    return 0
                case .record:
                    return (repState?.hasNext ?? false) ? 20 : setRestTime
                }
            }
        }
        
        var initialRepState: RepState? {
            switch data.exercise.category {
            case .generic(_, _, let sideType):
                return sideType == .independent ? .binary(first: true) : nil
            case .repeater(_, _, _):
                guard let max = dataSet[.reps]?.num else { return nil }
                return .multi(current: 0, max: max)
            case .maxHang(_, let sideType):
                return sideType == .independent ? .binary(first: true) : nil
            case .campus(_, let mirrorSides):
                return mirrorSides ? .binary(first: true) : nil
            }
        }
        
        var prev: ViewState? {
            switch exerciseState {
            case .ready:
                // If at the beginning, nowhere to go
                return nil
            case .active, .rest, .record:
                // Keep it simple, just go back to the beginning of the exercise
                return nextState(.ready, initialRepState)
            }
        }
        
        /// If not nil, stay within this exercise and move to another state
        /// Otherwise, the exercise should be changed
        var next: ViewState? {
            switch exerciseState {
            case .ready:
                // From ready, we go to the active state IF this exercise
                // uses a timer. Otherwise, we skip directly to data record
                return nextState(usesActiveTimer ? .active : .record, repState)
            case .active:
                // From active, we go to the rest state IF we need to show
                // more active states later. Otherwise, go directly to data record
                if let nextRep = repState?.next {
                    return nextState(.rest, nextRep)
                }
                return nextState(.record)
            case .rest:
                // From rest, we go back to the active state every time
                return nextState(.active, repState)
            case .record:
                // If we have more reps in data record, we must not be using
                // time. Therefore, stay in record and keep incrementing
                // until we are done. Repeat until no reps remain.
                if let nextRep = repState?.next {
                    return nextState(.record, nextRep)
                }
                return nil
            }
        }
        
        private func nextState(_ newExercise: ExerciseState, _ newRep: RepState? = nil) -> ViewState {
            return .init(data: data, setIndex: setIndex, exerciseState: newExercise, repState: newRep)
        }
        
        enum ExerciseState {
            /// Beginning of an exercise - only should enter in this state and never return
            /// All timed exercises start here - adds a delay before starting
            case ready
            /// Exercise in progress (time in generic, time on a hold)
            /// Repeater on period, time active in a generic exercise
            case active
            /// Exercise paused, but to be resumed after a delay
            /// Repeater off period, delay between exercises in L/R sets
            case rest
            /// The end period of an exercise, allows user input for data recording
            case record
        }
        
        enum RepState {
            /// Used for sided exercises (i.e. left/right sides)
            case binary(first: Bool)
            /// Used for exercises with multiple on/off states (repeaters)
            case multi(current: Int, max: Int)
            
            var hasNext: Bool {
                switch self {
                case .binary(let first):
                    first
                case .multi(let current, let max):
                    current < max
                }
            }
            
            var next: RepState? {
                if !hasNext {
                    return nil
                }
                switch self {
                case .binary(_):
                    return .binary(first: false)
                case .multi(let current, let max):
                    return .multi(current: current + 1, max: max)
                }
            }
            
            var text: String {
                switch self {
                case .binary(let first):
                    return first ? "Right" : "Left"
                case .multi(let current, let max):
                    return "Rep \(current)/\(max)"
                }
            }
        }
    }
}

struct ExerciseStateView: View {
    var titleLeading: String
    var titleTrailing: String?
    var subheadline: String?
    var setIndex: Int
    var numSets: Int
    var repText: String?
    
    init(titleLeading: String,
         titleTrailing: String? = nil,
         subheadline: String? = nil,
         setIndex: Int,
         numSets: Int,
         repText: String? = nil) {
        self.titleLeading = titleLeading
        self.titleTrailing = titleTrailing
        self.subheadline = subheadline
        self.setIndex = setIndex
        self.numSets = numSets
        self.repText = repText
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(titleLeading)
                Spacer()
                if let titleTrailing {
                    Text(titleTrailing)
                }
            }.font(.title)
                .bold()
            if let subheadline {
                Text(subheadline)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Set \(setIndex + 1)/\(numSets)")
                Spacer()
                if let repText {
                    Text(repText)
                }
            }.font(.title3)
                .fontWeight(.semibold)
        }.lineLimit(1)
    }
}

#Preview("Main", traits: .sampleData) {
    @Previewable @Query var sessions: [Session]
    NavigationStack {
        SessionLiveView(sessionData: sessions.filter({ !$0.data.isEmpty }).first!.data.first!)
    }.environmentObject(NavigationStore())
}

#Preview("State View") {
    Form {
        ExerciseStateView(titleLeading: "20mm HC", titleTrailing: "7/3s", subheadline: "7 reps @ 20 lbs", setIndex: 1, numSets: 5, repText: "Rep 1/5")
    }
}
