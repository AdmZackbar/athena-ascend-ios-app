//
//  ContentView.swift
//  AthenaAscendWatch Watch App
//
//  Created by Zach Wassynger on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var connectivity = SessionConnectivity.shared

    /// Local, watch-only entry values for the .rest-phase form. Seeded once per exercise/phase
    /// moment from the snapshot's suggested values, then left alone — never re-synced from the
    /// phone while the person is actively editing it here.
    @State private var restEntry = ExerciseEntryData(numLeft: 0, numRight: 0, weightLeft: 0, weightRight: 0)
    @State private var restEntryKey: String? = nil

    /// Local, watch-only entry values for the .off-phase single-value form.
    @State private var offCount: Int = 0
    @State private var offWeight: Double = 0
    @State private var offEntryKey: String? = nil

    private var snapshot: ActiveSessionSnapshot? {
        connectivity.latestSnapshot
    }

    var body: some View {
        Group {
            if let snapshot {
                sessionView(snapshot)
            } else {
                ContentUnavailableView("No Active Session", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .onAppear {
            seedFormsIfNeeded(snapshot)
        }
        .onChange(of: snapshot) { _, newValue in
            seedFormsIfNeeded(newValue)
        }
    }

    /// Re-seeds the local entry forms only when a *new* entry moment begins (a different
    /// exercise, set, or phase) — re-seeding on every snapshot update would stomp whatever the
    /// person is actively entering, which is exactly the thing this design avoids.
    private func seedFormsIfNeeded(_ snapshot: ActiveSessionSnapshot?) {
        guard let snapshot else { return }
        let key = "\(snapshot.sessionStartTime.timeIntervalSinceReferenceDate)-\(snapshot.setIndex)-\(snapshot.exerciseName)-\(snapshot.phase.rawValue)"
        if snapshot.phase == .rest, restEntryKey != key {
            restEntry = ExerciseEntryData(
                numLeft: snapshot.suggestedNumLeft,
                numRight: snapshot.suggestedNumRight,
                weightLeft: snapshot.suggestedWeightLeft,
                weightRight: snapshot.suggestedWeightRight
            )
            restEntryKey = key
        }
        if snapshot.phase == .off && snapshot.hasOffPhaseEntry && snapshot.timerEndDate == nil, offEntryKey != key {
            offCount = snapshot.suggestedNumRight
            offWeight = snapshot.suggestedWeightLeft
            offEntryKey = key
        }
    }

    @ViewBuilder
    private func sessionView(_ snapshot: ActiveSessionSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let routineName = snapshot.routineName {
                    Text(routineName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(snapshot.exerciseName)
                    .font(.headline)
                Text(snapshot.exerciseDetailText)
                    .font(.subheadline)
                Text(phaseLabel(snapshot.phase))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if snapshot.repMax > 0 {
                    Text("Rep \(snapshot.repCurrent)/\(snapshot.repMax)")
                        .font(.caption)
                }
                timerView(snapshot)
                if snapshot.phase == .rest {
                    restEntryForm(snapshot)
                } else if snapshot.phase == .off && snapshot.hasOffPhaseEntry && snapshot.timerEndDate == nil {
                    offEntryForm(snapshot)
                }
                controlRow(snapshot)
            }
            .padding()
        }
    }

    /// Native, system-driven countdown — no local polling. When paused (timerEndDate is nil
    /// but a duration exists), the exact remaining time is intentionally not shown; see the
    /// Design section of the implementation plan for why.
    @ViewBuilder
    private func timerView(_ snapshot: ActiveSessionSnapshot) -> some View {
        if let endDate = snapshot.timerEndDate {
            let startDate = endDate.addingTimeInterval(-snapshot.timerDuration)
            VStack(spacing: 4) {
                ProgressView(timerInterval: startDate...endDate, countsDown: true)
                Text(timerInterval: startDate...endDate, countsDown: true)
                    .font(.title2)
                    .monospacedDigit()
            }
        } else if snapshot.timerDuration > 0 {
            Text("Paused")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func restEntryForm(_ snapshot: ActiveSessionSnapshot) -> some View {
        VStack(alignment: .leading) {
            Stepper("\(restEntry.numLeft) \(snapshot.unitLabel)", value: $restEntry.numLeft, in: 0...1000)
            if snapshot.recordsWeight {
                Stepper(weightLabel(restEntry.weightLeft), value: $restEntry.weightLeft, in: -200...200, step: 5)
            }
            if snapshot.recordsDualSides {
                Stepper("\(restEntry.numRight) \(snapshot.unitLabel) (R)", value: $restEntry.numRight, in: 0...1000)
                if snapshot.recordsWeight {
                    Stepper(weightLabel(restEntry.weightRight, suffix: " (R)"), value: $restEntry.weightRight, in: -200...200, step: 5)
                }
            }
        }
    }

    /// The .off-phase mirror is always a single value (see the Design section's trace of
    /// genericRecordView's isRight check) — one count field, one weight field, always
    /// presented as "Right" to match the phone's own label here.
    @ViewBuilder
    private func offEntryForm(_ snapshot: ActiveSessionSnapshot) -> some View {
        VStack(alignment: .leading) {
            Text("Right")
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper("\(offCount) \(snapshot.unitLabel)", value: $offCount, in: 0...1000)
            if snapshot.recordsWeight {
                Stepper(weightLabel(offWeight), value: $offWeight, in: -200...200, step: 5)
            }
        }
    }

    @ViewBuilder
    private func controlRow(_ snapshot: ActiveSessionSnapshot) -> some View {
        HStack {
            Spacer()
            Button {
                connectivity.sendCommand(.prev)
            } label: {
                Image(systemName: "arrowshape.backward.circle")
            }
            Spacer()
            Button {
                connectivity.sendCommand(.toggleTimer)
            } label: {
                Image(systemName: snapshot.timerEndDate != nil ? "pause.circle" : "play.circle")
            }
            Spacer()
            Button {
                connectivity.sendCommand(.next(data: nextPayload(for: snapshot)))
            } label: {
                Image(systemName: "arrowshape.forward.circle")
            }
            Spacer()
        }
        .font(.system(size: 28))
        .buttonStyle(.plain)
    }

    /// Only the .rest and .off-with-open-entry moments have anything to send; every other
    /// phase's Next is a plain advance, matching the phone's own controlView behavior exactly.
    private func nextPayload(for snapshot: ActiveSessionSnapshot) -> ExerciseEntryData? {
        if snapshot.phase == .rest {
            return restEntry
        } else if snapshot.phase == .off && snapshot.hasOffPhaseEntry && snapshot.timerEndDate == nil {
            // Duplicate the single value across both sides so the phone's toGeneric(_:useAlt:)
            // treats it as one confirmed value rather than manufacturing a spurious alt value.
            return ExerciseEntryData(numLeft: offCount, numRight: offCount, weightLeft: offWeight, weightRight: offWeight)
        }
        return nil
    }

    private func phaseLabel(_ phase: ActiveSessionSnapshot.Phase) -> String {
        switch phase {
        case .ready: return "Ready"
        case .on: return "Active"
        case .off: return "Off"
        case .rest: return "Rest"
        }
    }

    private func weightLabel(_ weight: Double, suffix: String = "") -> String {
        "\(weight.formatted(.number.precision(.fractionLength(0)))) lb\(suffix)"
    }
}

#Preview {
    ContentView()
}
