//
//  SessionLiveView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/28/26.
//

import SwiftData
import SwiftUI
internal import Combine

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Allows the user to progress a `Session` through each super set, exercise, and set.
struct SessionLiveView: View {
    @Environment(\.dismiss) var dismiss
    
    let session: Session

    @State private var state: ViewState
    @State private var commandCenter = SessionCommandCenter.shared
    // Timer vars
    /// Set to the start time of the timer (in seconds)
    var timerDuration: Duration {
        switch state {
        case .inSet(let state):
            return .seconds(state.maxTimeSeconds)
        default:
            return .zero
        }
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
    /// The in-progress edits for the current set's actual data, shown during the record phase
    @State private var draftSet: ExerciseData.DataSet = [:]
    /// If true, the timer is allowed to modify the state when it finishes
    var allowTimerNext: Bool {
        switch state {
        case .inSet(let s):
            return s.exerciseState != .record || timerNextOverride
        default: return true
        }
    }
    
    init(session: Session, initialState: ViewState? = nil) {
        self.session = session
        self.state = initialState ?? .preSet(0)
    }
    
    var body: some View {
        mainView()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .background(background)
            .toolbar(content: toolbarContent)
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

    var title: String {
        return session.superSets[state.superSetIndex].name
    }

    /// Snapshot of the live session state, mirrored to the watch and the Live Activity
    /// whenever it changes.
    var activeSessionSnapshot: ActiveSessionSnapshot {
        let superSetName = session.superSets[state.superSetIndex].name
        let routineName = session.routine?.name
        switch state {
        case .preSet:
            return ActiveSessionSnapshot(
                sessionStartTime: session.startTime,
                routineName: routineName,
                superSetName: superSetName,
                phase: .preSet,
                exerciseName: nil,
                exerciseDetailText: nil,
                setIndex: 0,
                setCount: 0,
                repText: nil,
                timerEndDate: nil,
                timerDuration: 0
            )
        case .postSet:
            return ActiveSessionSnapshot(
                sessionStartTime: session.startTime,
                routineName: routineName,
                superSetName: superSetName,
                phase: .postSet,
                exerciseName: nil,
                exerciseDetailText: nil,
                setIndex: 0,
                setCount: 0,
                repText: nil,
                timerEndDate: nil,
                timerDuration: 0
            )
        case .inSet(let s):
            return ActiveSessionSnapshot(
                sessionStartTime: session.startTime,
                routineName: routineName,
                superSetName: superSetName,
                phase: snapshotPhase(for: s.exerciseState),
                exerciseName: s.exerciseName,
                exerciseDetailText: s.exerciseDetails,
                setIndex: s.setIndex,
                setCount: s.data.expectedData.count,
                repText: s.repText,
                timerEndDate: timerEndDate,
                timerDuration: timerDuration / .seconds(1)
            )
        }
    }

    /// Maps this view's SetState.ExerciseState to the shared, Codable DTO's Phase, keeping
    /// the Shared/ types free of any dependency on this view's private types.
    private func snapshotPhase(for state: SetState.ExerciseState) -> ActiveSessionSnapshot.Phase {
        switch state {
        case .ready: return .ready
        case .active: return .active
        case .rest: return .rest
        case .record: return .record
        }
    }

    /// Applies a command received from the watch or Live Activity, exactly as if the phone's
    /// own matching button had been tapped.
    private func handleRemoteCommand(_ command: SessionCommand?) {
        guard let command else { return }
        switch command {
        case .prev:
            prev()
        case .toggleTimer:
            // Mirrors controlView's own `.disabled(elapsedSeconds >= timerDuration)`.
            if elapsedSeconds < timerDuration {
                toggleTimer()
            }
        case .next:
            next()
        }
        commandCenter.consume()
    }
    
    /// The background color of the view
    var background: some ShapeStyle {
        switch state {
        case .preSet(_), .postSet(_):
            return Color(uiColor: .systemGroupedBackground)
        case .inSet(let s):
            switch s.exerciseState {
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
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarTitleMenu {
            ForEach(session.superSets.enumerated(), id: \.offset) { offset, superSet in
                Menu(superSet.name) {
                    let exerciseData = session.data
                        .sorted(by: { $0.position < $1.position })
                        .filter({ $0.position.superSetIndex == offset })
                    Button {
                        update(.preSet(offset))
                    } label: {
                        if state.superSetIndex == offset {
                            Label("Restart Super Set", systemImage: "arrow.trianglehead.counterclockwise")
                        } else {
                            Label("Start Super Set", systemImage: "play")
                        }
                    }
                    ForEach(exerciseData.enumerated(), id: \.offset) { offset, d in
                        Menu(d.exercise.name) {
                            ForEach(0..<d.expectedData.count, id: \.self) { setIndex in
                                Button("Set \(setIndex + 1)") {
                                    update(.inSet(.init(data: d, setIndex: setIndex)))
                                }
                            }
                        }.disabled(d.expectedData.isEmpty)
                    }
                }
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "arrow.turn.left.up")
            }
        }
        if state.isInSet {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    next(skip: true)
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }
            }
        }
    }
    
    @ViewBuilder
    func mainView() -> some View {
        switch state {
        case .preSet(let index):
            preSetView(index)
        case .inSet(let s):
            setView(s)
        case .postSet(let index):
            postSetView(index)
        }
    }
    
    @ViewBuilder
    func preSetView(_ index: Int) -> some View {
        ZStack(alignment: .bottom) {
            Form {
                ForEach(session.data.filter({ $0.position.superSetIndex == index }).sorted(by: { $0.position < $1.position })) { d in
                    Section {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            ForEach(d.expectedData.enumerated(), id: \.offset) { offset, setData in
                                GridRow(alignment: .top) {
                                    Text("Set \(offset + 1)")
                                        .fontWeight(.semibold)
                                    VStack(alignment: .leading) {
                                        Text(setData.getSummary() ?? "N/A")
                                        if setData.hasAlt {
                                            Text(setData.getSummary(useAlt: true) ?? "N/A")
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(d.exercise.name)
                    }
                }
            }.padding(.bottom, 64)
            Button {
                next()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.title)
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.glass)
                .padding([.leading, .trailing])
        }
    }
    
    @ViewBuilder
    func postSetView(_ index: Int) -> some View {
        ZStack(alignment: .bottom) {
            Form {
                ForEach(session.data.filter({ $0.position.superSetIndex == index }).sorted(by: { $0.position < $1.position })) { d in
                    Section {
                        ExerciseDataEntryView(data: d)
                        TextField("Notes", text: .init(get: {
                            d.notes
                        }, set: { newValue in
                            d.notes = newValue
                        }))
                    } header: {
                        Text(d.exercise.name)
                    }
                }
            }.padding(.bottom, 64)
            Button {
                next()
            } label: {
                if index + 1 < session.superSets.count {
                    Label("Next", systemImage: "arrow.right")
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Label("Finish", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }.buttonStyle(.glass)
                .padding([.leading, .trailing])
        }
    }
    
    @ViewBuilder
    func setView(_ s: SetState) -> some View {
        VStack(spacing: 4) {
            headerView(s)
            if s.exerciseState == .ready {
                prevDataView(s)
            } else if s.exerciseState == .record {
                recordEntryView(s)
                nextSetView(s)
            }
            Spacer()
            if timerDuration > .zero {
                timerView(s)
            }
            controlView()
                .padding(.top, 12)
        }.padding([.leading, .trailing])
            .ignoresSafeArea(.keyboard)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
    }

    @ViewBuilder
    func recordEntryView(_ s: SetState) -> some View {
        Group {
            VStack(spacing: 8) {
                DataSetEditor(exercise: s.data.exercise, dataSet: $draftSet, sides: sides(for: s))
                    .buttonStyle(.glass)
            }.padding()
        }.glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.top, 4)
    }
    
    @ViewBuilder
    func headerView(_ s: SetState) -> some View {
        let numSets = s.data.expectedData.count
        let subheadline = s.exerciseDetails
        switch s.data.exercise.category {
        case .generic(let name, _, _):
            ExerciseStateView(titleLeading: name, subheadline: subheadline, setIndex: s.setIndex, numSets: numSets, repText: s.repText)
        case .repeater(let tag, let timeOn, let timeOff):
            ExerciseStateView(titleLeading: tag, titleTrailing: "\(timeOn)s/\(timeOff)s", subheadline: subheadline, setIndex: s.setIndex, numSets: numSets, repText: s.repText)
        case .maxHang(let tag, _):
            ExerciseStateView(titleLeading: tag, subheadline: subheadline, setIndex: s.setIndex, numSets: numSets, repText: s.repText)
        case .campus(let name, _):
            ExerciseStateView(titleLeading: name, subheadline: subheadline, setIndex: s.setIndex, numSets: numSets, repText: s.repText)
        }
    }
    
    @ViewBuilder
    func prevDataView(_ s: SetState) -> some View {
        if let routine = session.routine, let d = s.data.exercise.data.filter({ $0.session.routine == routine && $0.session.id != session.id && $0.position == s.data.position && $0.actualData.count > s.setIndex }).sorted(by: { ($0.session.startTime, $0.position) > ($1.session.startTime, $1.position) }).first {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.session.startTime.formatted(date: .numeric, time: .omitted))
                        .bold()
                        .foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 8) {
                        Text("Set \(s.setIndex + 1):")
                            .fontWeight(.semibold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.actualData[s.setIndex].getSummary(useAlt: s.repState?.hasNext ?? false) ?? "N/A")
                            if case .text(let notes) = d.actualData[s.setIndex][.notes] {
                                Text(notes)
                                    .font(.subheadline)
                                    .italic()
                            }
                        }
                        Spacer()
                    }.font(.title3)
                }.padding()
            }.glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 4)
        } else if let d = s.data.exercise.data.filter({ $0.session.id != session.id && session.athletes.contains($0.athlete) }).sorted(by: { ($0.session.startTime, $0.position) > ($1.session.startTime, $1.position) }).first {
            HStack {
                ExerciseDataEntryView(data: d, headerType: .date)
                    .font(.title3)
                    .padding()
                Spacer()
            }.glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    func nextSetView(_ current: SetState) -> some View {
        if case .inSet(let next) = nextState {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if current.data.position == next.data.position {
                        // Same exercise, next set
                        Text("Next Set (\(next.setIndex + 1)/\(next.data.expectedData.count))")
                            .font(.body)
                            .bold()
                            .foregroundStyle(.secondary)
                        if let details = next.exerciseDetails {
                            Text(details)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .italic()
                        }
                    } else {
                        // New exercise
                        Text("Next Exercise")
                            .font(.body)
                            .bold()
                            .foregroundStyle(.secondary)
                        Text(next.exerciseName)
                            .font(.title2)
                            .bold()
                        if let details = next.exerciseDetails {
                            Text(details)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .italic()
                        }
                    }
                }.padding()
                Spacer()
            }.glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    func timerView(_ s: SetState) -> some View {
        // TODO other cases
        let text: String = {
            switch s.exerciseState {
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
        let countDown: Bool = {
            switch s.exerciseState {
            case .active:
                switch s.data.exercise.category {
                case .repeater(_, _, _): return true
                default: return false
                }
            default: return true
            }
        }()
        TimerRingView(text: text, textCountDown: countDown, timerDuration: timerDuration, elapsedSeconds: elapsedSeconds, progress: progress)
    }
    
    @ViewBuilder
    func controlView() -> some View {
        HStack(spacing: 24) {
            Spacer()
            Button(action: prev) {
                Image(systemName: "arrowshape.backward.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .padding(8)
            }.buttonStyle(.glass)
                .buttonBorderShape(.circle)
            Button(action: toggleTimer) {
                Image(systemName: isTimerValid ? "pause.fill" : "play.fill")
                    .resizable()
                    .scaledToFit()
                    .offset(x: isTimerValid ? 0 : 6)
                    .frame(width: 48, height: 48)
                    .padding(16)
                    .transaction { transaction in
                        // Disable icon transition animation
                        transaction.animation = nil
                    }
            }.buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(elapsedSeconds >= timerDuration)
            Button {
                next()
            } label: {
                Image(systemName: allowTimerNext || elapsedSeconds >= timerDuration ? "arrowshape.forward.fill" : "checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .padding(8)
                    .transaction { transaction in
                        // Disable icon transition animation
                        transaction.animation = nil
                    }
            }.buttonStyle(.glass)
                .buttonBorderShape(.circle)
            Spacer()
        }.buttonStyle(.plain)
    }
    
    // State functions
    
    func prev() {
        // First try to go back to the prev exercise state
        // Then try to move to the prev exercise
        if let prev = state.prev ?? prevState {
            update(prev)
        } else {
            // Otherwise at least stop timer
            stopAndResetTimer()
        }
    }
    
    /// Attempts to advance the state to the next phase of the
    /// current exercise, or to the next applicable exercise.
    /// If no exercises remain, this view is exited
    func next(skip: Bool = false) {
        // Persist any data entered during the record phase before advancing,
        // even if this press doesn't advance the state yet (see guard below)
        if !skip, let s = recordSetState {
            commitDraft(for: s)
        }
        guard allowTimerNext || elapsedSeconds >= timerDuration else {
            timerNextOverride = true
            return
        }
        // First try to advance to the next exercise state
        // (if we are not skipping)
        if !skip, let next = state.next {
            update(next)
            startTimer()
        } else if let nextState {
            // Otherwise try to move to the next exercise
            update(nextState)
            startTimer()
        } else {
            // Session is complete, clean up and exit
            stopAndResetTimer()
            dismiss()
        }
    }
    
    /// ALL writes to `state` should go through this method
    /// prev is an exception, since it does not want to auto-start timer
    func update(_ newState: ViewState) {
        // Stop timer first
        stopAndResetTimer()
        // Advance to next state, reset flags
        state = newState
        timerNextOverride = false
        // Seed the data entry draft whenever we land on a record phase
        if case .inSet(let s) = newState, s.exerciseState == .record {
            seedDraft(for: s)
        }
    }

    // ****************** //
    // DATA ENTRY HELPERS //
    // ****************** //

    /// The current `SetState`, if we are in the record phase of an exercise.
    private var recordSetState: SetState? {
        if case .inSet(let s) = state, s.exerciseState == .record {
            return s
        }
        return nil
    }

    /// Determines which side(s) of a (potentially) mirrored exercise should be
    /// exposed for editing during this record phase, based on the current rep state.
    private func sides(for s: SetState) -> DataSetEditor.Sides {
        guard s.data.exercise.canMirror else { return .single }
        switch s.repState {
        case .binary(let first):
            return first ? .right : .left
        case .multi(let current, let max):
            if max != 2 {
                // Currently not used, since repeaters aren't mirrored
                return .split
            }
            return current == 1 ? .right : .left
        case .none:
            // No side-specific rep state means both sides are recorded in this pass
            return .split
        }
    }

    /// Populates `draftSet` from any data already recorded for this set,
    /// falling back to the most recently recorded set and the expected/planned data.
    private func seedDraft(for s: SetState) {
        let data = s.data
        let setIndex = s.setIndex
        if setIndex < data.actualData.count {
            // Already (at least partially) recorded - e.g. returning to the same
            // set for the other side of a mirrored exercise
            draftSet = data.actualData[setIndex]
        } else {
            // This set has no data of its own yet, so notes from the previous
            // set shouldn't carry forward - only the numeric fields are a useful default
            var seed = data.actualData.last ?? [:]
            seed.removeValue(forKey: .notes)
            if setIndex < data.expectedData.count {
                seed.override(data.expectedData[setIndex].expectedToActual())
            }
            draftSet = seed
        }
    }

    /// Writes `draftSet` back to the underlying `ExerciseData`.
    private func commitDraft(for s: SetState) {
        let data = s.data
        let setIndex = s.setIndex
        var actual = data.actualData
        while actual.count <= setIndex {
            actual.append([:])
        }
        let showAlt = sides(for: s) != .single
        actual[setIndex] = draftSet.normalized(canMirror: data.exercise.canMirror, showAlt: showAlt)
        data.actualData = actual
    }
    
    private var prevState: ViewState? {
        let sortedData = session.data
            // Need to have data to go on
            .filter({ !$0.expectedData.isEmpty })
            // Sort by super set, then by exercise index DESCENDING
            .sorted(by: { $0.position > $1.position })
        switch state {
        case .preSet(let index):
            // Try to go back to the prev post-set
            if index > 0 {
                return .postSet(index - 1)
            }
        case .inSet(let s):
            // First check within the super set
            switch session.superSets[s.superSetIndex].order {
            case .bfs:
                // First check behind in the prev exercise for the same set index
                if let prev = sortedData.filter({ $0.position.superSetIndex == s.superSetIndex && $0.position.setIndex < s.exerciseIndex && $0.expectedData.count > s.setIndex }).first {
                    return .inSet(.init(data: prev, setIndex: s.setIndex))
                }
                // Then check all if any can support the prev set index
                if s.setIndex > 0, let prev = sortedData.filter({ $0.position.superSetIndex == s.superSetIndex && $0.expectedData.count > s.setIndex - 1 }).first {
                    return .inSet(.init(data: prev, setIndex: s.setIndex - 1))
                }
            case .dfs:
                // First try to go back to the prev set of the same exercise
                if s.setIndex > 0 {
                    return .inSet(.init(data: s.data, setIndex: s.setIndex - 1))
                }
                // Then try to move to the prev exercise (first set)
                if let prev = sortedData.filter({ $0.position.superSetIndex == s.superSetIndex && $0.position.setIndex < s.exerciseIndex }).first {
                    return .inSet(.init(data: prev, setIndex: prev.expectedData.count - 1))
                }
            }
            // Go back to the pre-set for this super set
            return .preSet(s.data.position.superSetIndex)
        case .postSet(let index):
            // Go to the last exercise in this super set (or prev)
            if let prev = sortedData.filter({ $0.position.superSetIndex == index }).first {
                return .inSet(.init(data: prev, setIndex: prev.expectedData.count - 1))
            }
            // Otherwise, go to the pre-set of this super set
            return .preSet(index)
        }
        // Otherwise, nowhere to go
        return nil
    }
    
    private var nextState: ViewState? {
        let sortedData = session.data
            // Need to have data to go on
            .filter({ !$0.expectedData.isEmpty })
            // Sort by super set, then by exercise index
            .sorted(by: { $0.position < $1.position })
        switch state {
        case .preSet(let index):
            // Go to the first exercise in this super set (or next applicable)
            if let next = sortedData.filter({ $0.position.superSetIndex == index }).first {
                return .inSet(.init(data: next, setIndex: 0))
            }
            // Otherwise, go to the post-set of this super set
            return .postSet(index)
        case .inSet(let s):
            // First check within the set
            switch session.superSets[s.superSetIndex].order {
            case .bfs:
                // First check ahead in the next exercise for the same set index
                if let next = sortedData.filter({ $0.position.superSetIndex == s.superSetIndex && $0.position.setIndex > s.exerciseIndex && $0.expectedData.count > s.setIndex }).first {
                    return .inSet(.init(data: next, setIndex: s.setIndex))
                }
                // Then check all if any can support the next set index
                if let next = sortedData.filter({ $0.position.superSetIndex == s.superSetIndex && $0.expectedData.count > s.setIndex + 1 }).first {
                    return .inSet(.init(data: next, setIndex: s.setIndex + 1))
                }
            case .dfs:
                // First try to advance to the next set of the same exercise
                if s.setIndex + 1 < s.data.expectedData.count {
                    return .inSet(.init(data: s.data, setIndex: s.setIndex + 1))
                }
                // Then try to move to the next exercise (first set)
                if let next = sortedData.filter({ $0.position.superSetIndex == s.superSetIndex && $0.position.setIndex > s.exerciseIndex }).first {
                    return .inSet(.init(data: next, setIndex: 0))
                }
            }
            // Go to the post-set for this super set
            return .postSet(s.superSetIndex)
        case .postSet(let index):
            // Try to go to the next super set
            if index + 1 < session.superSets.count {
                return .preSet(index + 1)
            }
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
    
    /// Top level state that includes pre, in, and post super-set states.
    enum ViewState: Hashable {
        case preSet(_ index: Int)
        case inSet(_ state: SetState)
        case postSet(_ index: Int)
        
        var isInSet: Bool {
            switch self {
            case .inSet(_): return true
            default: return false
            }
        }
        
        var prev: ViewState? {
            switch self {
            case .inSet(let s):
                if let prev = s.prev {
                    return .inSet(prev)
                }
            default:
                break
            }
            return nil
        }
        
        var next: ViewState? {
            switch self {
            case .inSet(let s):
                if let next = s.next {
                    return .inSet(next)
                }
            default:
                break
            }
            return nil
        }
        
        var superSetIndex: Int {
            switch self {
            case .preSet(let index), .postSet(let index):
                return index
            case .inSet(let s):
                return s.data.position.superSetIndex
            }
        }
    }
    
    /// Contains state information while traversing the exercises within a super set.
    struct SetState: Hashable {
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
            return data.session.superSets[superSetIndex].restTime
        }
        
        var maxTimeSeconds: Int {
            if !usesActiveTimer {
                // Unless we are recording (and need to use set rest time
                // before the next exercise), untimed exercises have no max time
                return exerciseState == .record ? setRestTime : 0
            }
            switch exerciseState {
            case .ready:
                // Ready time is 10s for all timed exercises
                return 10
            case .active:
                switch data.exercise.category {
                case .repeater(_, let timeOn, _): return timeOn
                default:
                    // Default to 60s if not explicitly set
                    if (repState?.hasNext ?? false) {
                        return dataSet[.timeAlt]?.max ?? dataSet[.time]?.max ?? 60
                    }
                    return dataSet[.time]?.max ?? 60
                }
            case .rest:
                switch data.exercise.category {
                case .generic(_, _, _): return 10
                case .repeater(_, _, let timeOff): return timeOff
                // Changeover period for max hang is longer than generic
                case .maxHang(_, _): return 20
                // Unreachable
                default: return 0
                }
            case .record:
                return setRestTime
            }
        }
        
        var exerciseName: String {
            switch data.exercise.category {
            case .generic(let name, _, _):
                return name
            case .repeater(let tag, _, _):
                return tag
            case .maxHang(let tag, _):
                return tag
            case .campus(let name, _):
                return name
            }
        }
        
        var exerciseDetails: String? {
            switch data.exercise.category {
            case .generic(_, _, _):
                return dataSet.getSummary(useAlt: repState?.hasNext ?? false)
            case .repeater(_, _, _):
                if let reps = dataSet.getText(.reps), let weight = dataSet.getText(.weight) {
                    return "\(reps) @ \(weight)"
                }
                return dataSet.getSummary()
            case .maxHang(_, _):
                if let time = dataSet.getText(.time), let weight = dataSet.getText(.weight) {
                    return "\(weight) for \(time)"
                }
                return dataSet.getSummary(useAlt: repState?.hasNext ?? false)
            case .campus(_, _):
                if repState?.hasNext ?? false {
                    return dataSet[.campusAlt]?.text ?? dataSet[.campus]?.alt.text
                }
                return dataSet[.campus]?.text
            }
        }

        /// The rep/side indicator shown in the header and mirrored into the snapshot, so the
        /// phone, watch, and Live Activity never disagree on this text.
        var repText: String? {
            repState?.text
        }

        var initialRepState: RepState? {
            switch data.exercise.category {
            case .generic(_, _, let sideType):
                return sideType == .independent ? .binary(first: true) : nil
            case .repeater(_, _, _):
                guard let max = dataSet[.reps]?.num else { return nil }
                return .multi(current: 1, max: max)
            case .maxHang(_, let sideType):
                return sideType == .independent ? .binary(first: true) : nil
            case .campus(_, let mirrorSides):
                // Technically binary, but not left vs right
                // Use multi for the rep 1/2 text
                return mirrorSides ? .multi(current: 1, max: 2) : nil
            }
        }
        
        var prev: SetState? {
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
        var next: SetState? {
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
                // time. Therefore, move back to ready for the next rep
                if let nextRep = repState?.next {
                    return nextState(.ready, nextRep)
                }
                return nil
            }
        }
        
        private func nextState(_ newExercise: ExerciseState, _ newRep: RepState? = nil) -> SetState {
            return .init(data: data, setIndex: setIndex, exerciseState: newExercise, repState: newRep)
        }
        
        enum ExerciseState: Hashable {
            /// Beginning of an exercise - entry point for every type and USUALLY don't return here
            /// All timed exercises start here - adds a delay before starting
            /// In the case of untimed exercises, this is used between reps
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
        
        enum RepState: Hashable {
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
    
    var headerSize: CGFloat {
        let textLength = (titleLeading.count + (titleTrailing?.count ?? 0))
        if textLength < 16 {
            return 40
        } else if textLength < 22 {
            return 32
        } else {
            return 24
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(titleLeading)
                Spacer()
                if let titleTrailing {
                    Text(titleTrailing)
                }
            }.font(.system(size: headerSize))
                .lineLimit(1)
            HStack {
                Text("Set \(setIndex + 1)/\(numSets)")
                Spacer()
                if let repText {
                    Text(repText)
                }
            }.font(.system(size: 32))
            if let subheadline {
                Text(subheadline)
                    .font(.title)
                    .lineLimit(1...2)
            }
        }.fontWeight(.heavy)
    }
}

#Preview("Main", traits: .sampleData) {
    @Previewable @Query(sort: \Session.startTime) var sessions: [Session]
    NavigationStack {
        Form {
            ForEach(sessions, id: \.uuid) { session in
                NavigationLink {
                    SessionLiveView(session: session)
                } label: {
                    VStack(alignment: .leading) {
                        Text(session.startTime.formatted())
                        Text(session.athletes.map({ $0.name }).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }.environmentObject(NavigationStore())
}

#Preview("State View") {
    Form {
        ExerciseStateView(titleLeading: "20mm HC", titleTrailing: "7s/3s", subheadline: "7 reps @ 20 lbs", setIndex: 1, numSets: 5, repText: "Rep 1/5")
        ExerciseStateView(titleLeading: "Basic Ladder", subheadline: "B1-R3-L5-R7-L9-B9", setIndex: 3, numSets: 4, repText: "Rep 1/2")
        ExerciseStateView(titleLeading: "Ninja kick with pancakes", subheadline: "30s, 40 lbs, 30\"", setIndex: 1, numSets: 12, repText: "Left")
    }
}
