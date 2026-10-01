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
                        if let details = context.state.exerciseDetailText {
                            Text(details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                Text(s.exerciseName ?? s.superSetName)
                    .font(.headline)
                Spacer()
                if s.exerciseName != nil {
                    Text("\(s.setIndex + 1)/\(s.setCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let details = s.exerciseDetailText {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(s.phase.displayName)
                    .font(.subheadline)
                    .bold()
                if let repText = s.repText {
                    Text(repText)
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
            Text(s.exerciseName ?? s.superSetName)
                .font(.headline)
            if s.exerciseName != nil {
                Text("\(s.setIndex + 1)/\(s.setCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        } else if s.exerciseName != nil {
            Text("\(s.setIndex + 1)/\(s.setCount)")
                .font(.caption)
        } else {
            Text(s.phase.displayName)
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

    /// Mirrors SessionLiveView.background's phase-to-color mapping, minus the progress-based
    /// .mix (the snapshot doesn't carry per-second progress, and doesn't need to for a Live
    /// Activity's tint).
    private func phaseColor(_ phase: ActiveSessionSnapshot.Phase) -> Color? {
        switch phase {
        case .ready, .rest: return .ready
        case .active: return .active
        case .record: return .rest
        case .preSet, .postSet: return nil
        }
    }
}

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(sessionStartTime: .now, routineName: "Push Day")
    }
}

extension ActiveSessionSnapshot {
    fileprivate static var previewActive: ActiveSessionSnapshot {
        ActiveSessionSnapshot(
            sessionStartTime: .now,
            routineName: "Push Day",
            superSetName: "Warm-up",
            phase: .active,
            exerciseName: "Bench Press",
            exerciseDetailText: "3 x 8-10 @ 135 lbs",
            setIndex: 1,
            setCount: 4,
            repText: nil,
            timerEndDate: Date().addingTimeInterval(45),
            timerDuration: 60
        )
    }

    fileprivate static var previewRecord: ActiveSessionSnapshot {
        var s = previewActive
        s.phase = .record
        s.timerEndDate = nil
        s.timerDuration = 90
        s.repText = "Rep 2/3"
        return s
    }

    fileprivate static var previewPreSet: ActiveSessionSnapshot {
        ActiveSessionSnapshot(
            sessionStartTime: .now,
            routineName: "Push Day",
            superSetName: "Warm-up",
            phase: .preSet,
            exerciseName: nil,
            exerciseDetailText: nil,
            setIndex: 0,
            setCount: 0,
            repText: nil,
            timerEndDate: nil,
            timerDuration: 0
        )
    }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    ActiveSessionSnapshot.previewActive
    ActiveSessionSnapshot.previewRecord
    ActiveSessionSnapshot.previewPreSet
}
