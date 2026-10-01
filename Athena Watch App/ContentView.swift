//
//  ContentView.swift
//  Athena Watch Watch App
//
//  Created by Zach Wassynger on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var connectivity = SessionConnectivity.shared

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
    }

    @ViewBuilder
    private func sessionView(_ snapshot: ActiveSessionSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(snapshot.exerciseName ?? snapshot.superSetName)
                    Spacer()
                    if snapshot.exerciseName != nil {
                        Text("(\(snapshot.setIndex + 1)/\(snapshot.setCount))")
                    }
                }.font(.subheadline)
                if let details = snapshot.exerciseDetailText {
                    Text(details)
                        .font(.caption)
                }
                Text(snapshot.phase.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let repText = snapshot.repText {
                    Text(repText)
                        .font(.caption)
                }
                timerView(snapshot)
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
            ProgressView(timerInterval: startDate...endDate, countsDown: true)
        } else if snapshot.timerDuration > 0 {
            Text("Paused")
                .font(.title3)
                .foregroundStyle(.secondary)
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
            }.font(.system(size: 64))
                .disabled(snapshot.timerDuration == 0)
            Spacer()
            Button {
                connectivity.sendCommand(.next)
            } label: {
                Image(systemName: "arrowshape.forward.circle")
            }
            Spacer()
        }
        .font(.system(size: 48))
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
