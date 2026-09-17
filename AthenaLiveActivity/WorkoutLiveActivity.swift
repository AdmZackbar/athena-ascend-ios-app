//
//  WorkoutLiveActivity.swift
//  AthenaLiveActivity
//
//  Created by Zach Wassynger on 9/17/26.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context.state)
                .activityBackgroundTint(phaseColor(context.state.phase))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timeView(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.exerciseDetailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        controlRow(context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                compactTrailing(context.state)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(_ s: ActiveSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.exerciseName)
                    .font(.headline)
                Spacer()
                Text("\(s.setIndex + 1)/\(s.setCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(s.exerciseDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(s.phase.displayName)
                    .font(.subheadline)
                    .bold()
                if s.repMax > 0 {
                    Text("Rep \(s.repCurrent)/\(s.repMax)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                timeView(s)
            }
            controlRow(s)
        }
        .padding()
    }

    @ViewBuilder
    private func expandedLeading(_ s: ActiveSessionSnapshot) -> some View {
        VStack(alignment: .leading) {
            Text(s.exerciseName)
                .font(.headline)
            Text("\(s.setIndex + 1)/\(s.setCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Native, system-driven countdown so the Live Activity never needs a per-second update from
    /// the app — same range math as the watch's timerView (ContentView.swift).
    @ViewBuilder
    private func timeView(_ s: ActiveSessionSnapshot) -> some View {
        if let end = s.timerEndDate {
            Text(timerInterval: end.addingTimeInterval(-s.timerDuration)...end, countsDown: true)
                .monospacedDigit()
        } else if s.timerDuration > 0 {
            Text("Paused")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func compactTrailing(_ s: ActiveSessionSnapshot) -> some View {
        if s.timerEndDate != nil || s.timerDuration > 0 {
            timeView(s)
                .font(.caption)
        } else {
            Text("\(s.setIndex + 1)/\(s.setCount)")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func controlRow(_ s: ActiveSessionSnapshot) -> some View {
        HStack {
            Button(intent: PreviousExerciseIntent()) {
                Image(systemName: "arrowshape.backward.circle")
            }
            Spacer()
            Button(intent: ToggleWorkoutTimerIntent()) {
                Image(systemName: s.timerEndDate != nil ? "pause.circle" : "play.circle")
            }
            .disabled(s.timerDuration == 0)
            Spacer()
            Button(intent: NextExerciseIntent()) {
                Image(systemName: "arrowshape.forward.circle")
            }
        }
        .font(.system(size: 32))
        .buttonStyle(.plain)
    }

    /// Mirrors RoutineSessionView.background's phase-to-color mapping, minus the progress-based
    /// .mix (the snapshot doesn't carry per-second progress, and doesn't need to for a Live
    /// Activity's tint).
    private func phaseColor(_ phase: ActiveSessionSnapshot.Phase) -> Color {
        switch phase {
        case .ready, .off: return .ready
        case .on: return .active
        case .rest: return .rest
        }
    }
}

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(sessionStartTime: .now, routineName: "Push Day")
    }
}

extension ActiveSessionSnapshot {
    fileprivate static var previewRunning: ActiveSessionSnapshot {
        ActiveSessionSnapshot(
            sessionStartTime: .now,
            routineName: "Push Day",
            setName: "Warm-up",
            setIndex: 1,
            setCount: 4,
            exerciseName: "Bench Press",
            exerciseDetailText: "3 x 8-10 @ 135 lbs",
            phase: .on,
            repCurrent: 0,
            repMax: 0,
            timerEndDate: Date().addingTimeInterval(45),
            timerDuration: 60,
            recordsWeight: true,
            recordsDualSides: false,
            hasOffPhaseEntry: false,
            unitLabel: "reps",
            suggestedNumLeft: 0,
            suggestedNumRight: 0,
            suggestedWeightLeft: 0,
            suggestedWeightRight: 0
        )
    }

    fileprivate static var previewResting: ActiveSessionSnapshot {
        var s = previewRunning
        s.phase = .rest
        s.timerEndDate = nil
        s.timerDuration = 90
        s.suggestedNumLeft = 8
        s.suggestedWeightLeft = 135
        return s
    }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    ActiveSessionSnapshot.previewRunning
    ActiveSessionSnapshot.previewResting
}
