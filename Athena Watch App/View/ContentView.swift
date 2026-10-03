//
//  ContentView.swift
//  Athena Watch Watch App
//
//  Created by Zach Wassynger on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var connectivity = SessionConnectivity.shared
    @State private var workoutManager = WorkoutManager.shared
    @State private var selectedPage: Page = .session
    @State private var postWorkoutSheet: PostWorkoutSheet?
    @State private var showingEndConfirmation = false

    /// Pages of the swipeable `TabView`, mirroring the native Workout app's layout:
    /// controls on the left, the live session in the middle (the default), and metrics
    /// on the right. Only shown while a HealthKit workout is actually running.
    private enum Page: Hashable {
        case controls, session, metrics
    }

    /// The post-workout flow: summary first, then effort rating - as one `Identifiable`
    /// driving a single `.sheet(item:)`, so swapping from one to the other can't race with
    /// a separate dismiss like two independent `.sheet(isPresented:)` bindings would.
    private enum PostWorkoutSheet: Identifiable {
        case summary, effort
        var id: Self { self }
    }

    var body: some View {
        Group {
            if let metrics = workoutManager.metrics, metrics.state.isActive {
                TabView(selection: $selectedPage) {
                    controlsPage(metrics)
                        .tag(Page.controls)
                    SessionPageView(snapshot: connectivity.latestSnapshot, sendCommand: connectivity.sendCommand)
                        .tag(Page.session)
                    MetricsPageView(elapsedTime: workoutManager.currentElapsedTime(), metrics: workoutManager.metrics)
                        .tag(Page.metrics)
                }
                .tabViewStyle(.page)
            } else {
                SessionPageView(snapshot: connectivity.latestSnapshot, sendCommand: connectivity.sendCommand)
            }
        }
        .onChange(of: workoutManager.metrics?.state) { _, newValue in
            // Discarded (too-short) workouts skip the summary and rating entirely -
            // there's nothing saved to summarize or attach a rating to.
            if newValue == .ended {
                postWorkoutSheet = .summary
            }
        }
        .sheet(item: $postWorkoutSheet) { sheet in
            switch sheet {
            case .summary:
                WorkoutSummaryView(metrics: workoutManager.metrics) {
                    // Only offer a rating if the workout actually saved - `finishWorkout()`
                    // can legitimately return nil (e.g. the paired phone was locked).
                    postWorkoutSheet = workoutManager.lastWorkout != nil ? .effort : nil
                }
            case .effort:
                EffortRatingView()
            }
        }
    }

    // ************* //
    // WORKOUT PAGES //
    // ************* //

    /// End/pause controls for the mirrored HealthKit workout - deliberately separate from
    /// `SessionPageView`'s controls, which only ever drive the Athena exercise timer.
    @ViewBuilder
    private func controlsPage(_ metrics: WorkoutMetrics) -> some View {
        VStack(spacing: 12) {
            Button {
                workoutManager.togglePause()
            } label: {
                Label(metrics.state == .paused ? "Resume" : "Pause", systemImage: metrics.state == .paused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            Button(role: .destructive) {
                showingEndConfirmation = true
            } label: {
                Label("End", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .padding()
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                workoutManager.end()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Elapsed time, active/total energy, and heart rate - styled after the native
/// Workout app's metrics page (yellow time, white values).
private struct MetricsPageView: View {
    let elapsedTime: TimeInterval
    let metrics: WorkoutMetrics?
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedElapsedTime(elapsedTime))
                    .font(.title)
                    .foregroundStyle(.yellow)
                    .monospacedDigit()
                if let metrics {
                    let hrText = {
                        guard let heartRate = metrics.heartRate else { return "Unknown" }
                        return "\(Int(heartRate.rounded())) BPM"
                    }()
                    row(icon: "heart.fill", header: "Heart Rate", body: hrText)
                        .foregroundStyle(.pink)
                    row(icon: "flame.fill", header: "Active Energy", body: "\(Int(metrics.activeEnergy.rounded())) Cal")
                        .foregroundStyle(.orange.mix(with: .red, by: 0.5))
                    row(icon: "flame", header: "Total Energy", body: "\(Int(metrics.totalEnergy.rounded())) Cal")
                        .foregroundStyle(.orange.mix(with: .yellow, by: 0.25))
                }
                Spacer()
            }.padding()
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .imageScale(.small)
        }
    }
    
    @ViewBuilder
    private func row(icon: String, header: String, body: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: -2) {
                Text(header)
                    .font(.system(size: 12))
                    .fontWeight(.regular)
                Text(body)
            }
        }
    }
    
    private func formattedElapsedTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "00:00:00"
    }
}

/// The live-session page: the current super set/exercise, phase, timer, and prev/toggle/next
/// controls, or a placeholder when nothing is active.
private struct SessionPageView: View {
    var snapshot: ActiveSessionSnapshot?
    var sendCommand: (SessionCommand) -> Void

    var body: some View {
        if let snapshot {
            sessionView(snapshot)
        } else {
            ContentUnavailableView("No Active Session", systemImage: "figure.strengthtraining.traditional")
        }
    }

    @ViewBuilder
    private func sessionView(_ snapshot: ActiveSessionSnapshot) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.exerciseName ?? snapshot.superSetName)
                    .bold()
                if let details = snapshot.exerciseDetailText {
                    HStack(alignment: .top) {
                        Text(details)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        if snapshot.exerciseName != nil {
                            Text("Set \(snapshot.setIndex + 1)/\(snapshot.setCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
                HStack {
                    Text(snapshot.phase.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let repText = snapshot.repText {
                        Text(repText)
                            .font(.caption)
                    }
                }
                timerView(snapshot)
                if let fields = snapshot.recordFields, !fields.isEmpty {
                    RecordEntryView(fields: fields, sendCommand: sendCommand)
                        .id(recordSetKey(snapshot))
                }
                Spacer()
            }.padding([.leading, .trailing])
                .padding([.top, .bottom], -20)
        }.safeAreaInset(edge: .bottom) {
            controlRow(snapshot).padding(.bottom, -30)
        }
    }

    /// Identifies the current set/side, so `RecordEntryView`'s optimistic `pending` state
    /// resets (via `.id`) whenever the phone moves on to a different one.
    private func recordSetKey(_ snapshot: ActiveSessionSnapshot) -> String {
        "\(snapshot.exerciseName ?? "")|\(snapshot.setIndex)|\(snapshot.repText ?? "")"
    }

    /// Native, system-driven countdown while running — no local polling. When paused,
    /// `timerRemaining` is a one-time resync of the exact time left at the moment of pause
    /// (sent alongside `timerEndDate` going nil), rendered as a static, non-ticking value
    /// since nothing updates it again until the timer resumes.
    @ViewBuilder
    private func timerView(_ snapshot: ActiveSessionSnapshot) -> some View {
        if let endDate = snapshot.timerEndDate {
            let startDate = endDate.addingTimeInterval(-snapshot.timerDuration)
            ProgressView(timerInterval: startDate...endDate, countsDown: true)
        } else if let remaining = snapshot.timerRemaining {
            // Mimic active progress view layout
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: remaining, total: snapshot.timerDuration)
                Text(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else if snapshot.timerDuration > .zero {
            // Fallback
            Text("Paused")
        }
    }

    @ViewBuilder
    private func controlRow(_ snapshot: ActiveSessionSnapshot) -> some View {
        HStack(spacing: 8) {
            Button {
                sendCommand(.prev)
            } label: {
                Image(systemName: "arrowshape.backward.circle")
                    .font(.system(size: 32))
            }
            Spacer()
            Button {
                sendCommand(.toggleTimer)
            } label: {
                Image(systemName: snapshot.timerEndDate != nil ? "pause.circle" : "play.circle")
                    .font(.system(size: 48))
            }.disabled(snapshot.timerDuration == 0)
            Spacer()
            Button {
                sendCommand(.next)
            } label: {
                Image(systemName: "arrowshape.forward.circle")
                    .font(.system(size: 32))
            }
        }.padding([.leading, .trailing], 8)
            .buttonStyle(.plain)
    }
}

/// Steppers for the current set's actual data, shown during the record phase. Each stepper
/// optimistically displays the value it just sent - rather than waiting on the round-trip
/// back from the phone - so taps feel instant; `pending` is cleared once the phone's next
/// snapshot echoes back a matching value.
private struct RecordEntryView: View {
    var fields: [ActiveSessionSnapshot.RecordField]
    var sendCommand: (SessionCommand) -> Void

    @State private var pending: [ActiveSessionSnapshot.RecordField.Key: Double] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(fields) { field in
                row(for: field)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: fields) { _, newFields in
            for field in newFields where pending[field.key] == field.value {
                pending.removeValue(forKey: field.key)
            }
        }
    }

    @ViewBuilder
    private func row(for field: ActiveSessionSnapshot.RecordField) -> some View {
        let value = pending[field.key] ?? field.value
        Stepper(value: .init(get: {
            value
        }, set: { newValue in
            pending[field.key] = newValue
            sendCommand(.setRecordValue(key: field.key, value: newValue))
        }), in: field.range, step: field.step) {
            VStack(alignment: .center, spacing: 0) {
                Text(field.sideLabel.map { "\($0)" } ?? field.name)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(displayValue(value, field: field))
                    .font(.body)
            }
        }
    }

    private func displayValue(_ value: Double, field: ActiveSessionSnapshot.RecordField) -> String {
        let unit = value == 1 ? field.unitSingular : field.unitPlural
        if field.isDiscrete {
            return "\(Int(value.rounded()))\(unit)"
        }
        return "\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit)"
    }
}

#Preview {
    ContentView()
}

#if DEBUG
#Preview("Ready") {
    SessionPageView(snapshot: .init(
        sessionStartTime: .now,
        routineName: "Push Day",
        superSetName: "Bench Press",
        phase: .ready,
        exerciseName: "Bench Press",
        exerciseDetailText: "185 lb",
        setIndex: 1,
        setCount: 4,
        repText: "Rep 3/5",
        timerEndDate: nil,
        timerDuration: 0,
        timerRemaining: nil
    ), sendCommand: { _ in })
}

#Preview("Resting") {
    SessionPageView(snapshot: .init(
        sessionStartTime: .now,
        routineName: "Push Day",
        superSetName: "Bench Press",
        phase: .rest,
        exerciseName: "Bench Press",
        exerciseDetailText: "185 lb x 5",
        setIndex: 1,
        setCount: 4,
        repText: nil,
        timerEndDate: .now.addingTimeInterval(45),
        timerDuration: 90,
        timerRemaining: nil
    ), sendCommand: { _ in })
}

#Preview("Timer Paused") {
    SessionPageView(snapshot: .init(
        sessionStartTime: .now,
        routineName: "Push Day",
        superSetName: "Bench Press",
        phase: .rest,
        exerciseName: "Bench Press",
        exerciseDetailText: "185 lb x 5",
        setIndex: 1,
        setCount: 4,
        repText: nil,
        timerEndDate: nil,
        timerDuration: 90,
        timerRemaining: 52
    ), sendCommand: { _ in })
}

#Preview("Up Next (Super Set)") {
    SessionPageView(snapshot: .init(
        sessionStartTime: .now,
        routineName: "Full Body Circuit",
        superSetName: "Round 2",
        phase: .preSet,
        exerciseName: nil,
        exerciseDetailText: nil,
        setIndex: 0,
        setCount: 3,
        repText: nil,
        timerEndDate: nil,
        timerDuration: 0,
        timerRemaining: nil
    ), sendCommand: { _ in })
}

#Preview("Record") {
    let leftReps = ActiveSessionSnapshot.RecordField(key: .reps, name: "Reps", sideLabel: "Left", value: 8, isDiscrete: true, step: 1, range: 0...1000, unitSingular: " rep", unitPlural: " reps")
    let rightReps = ActiveSessionSnapshot.RecordField(key: .repsAlt, name: "Reps", sideLabel: "Right", value: 7, isDiscrete: true, step: 1, range: 0...1000, unitSingular: " rep", unitPlural: " reps")
    let leftWeight = ActiveSessionSnapshot.RecordField(key: .weight, name: "Weight", sideLabel: "Left", value: 25, isDiscrete: false, step: 5, range: -1000...1000, unitSingular: " lb", unitPlural: " lbs")
    let rightWeight = ActiveSessionSnapshot.RecordField(key: .weightAlt, name: "Weight", sideLabel: "Right", value: 25, isDiscrete: false, step: 5, range: -1000...1000, unitSingular: " lb", unitPlural: " lbs")
    let snapshot = ActiveSessionSnapshot(
        sessionStartTime: .now,
        routineName: "Push Day",
        superSetName: "1-Arm Row",
        phase: .record,
        exerciseName: "1-Arm Row",
        exerciseDetailText: "8 reps @ 25 lb",
        setIndex: 1,
        setCount: 4,
        repText: nil,
        timerEndDate: nil,
        timerDuration: 10,
        timerRemaining: 10,
        recordFields: [leftReps, rightReps, leftWeight, rightWeight]
    )
    SessionPageView(snapshot: snapshot, sendCommand: { _ in })
}

#Preview("Metrics") {
    let elapsedTime: TimeInterval = 345
    MetricsPageView(elapsedTime: elapsedTime, metrics: .init(state: .running, startDate: .now.addingTimeInterval(-elapsedTime), elapsedTime: elapsedTime, heartRate: 145, activeEnergy: 105, totalEnergy: 123))
}
#endif
