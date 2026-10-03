//
//  WorkoutSummaryView.swift
//  Athena Watch App
//
//  Created by Zach Wassynger on 10/1/26.
//

import SwiftUI

/// Recaps the stats of a workout after its completion
struct WorkoutSummaryView: View {
    let metrics: WorkoutMetrics?
    /// Called when the person dismisses this screen - `ContentView` decides whether to
    /// follow it with `EffortRatingView` (only if the workout actually saved).
    var onContinue: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Saved")
                    .font(.headline)
                    .fontWeight(.bold)
                if let metrics {
                    row(icon: "stopwatch", header: "Total Time", body: formattedElapsedTime(metrics.elapsedTime))
                        .foregroundStyle(.yellow)
                    let hrText = {
                        guard let heartRate = metrics.heartRate else { return "Unknown" }
                        return "\(Int(heartRate)) BPM"
                    }()
                    row(icon: "heart", header: "Average HR", body: hrText)
                        .foregroundStyle(.pink)
                    row(icon: "flame.fill", header: "Active Energy", body: "\(metrics.activeEnergy.formatted(.number.precision(.fractionLength(0)))) Cal")
                        .foregroundStyle(.orange.mix(with: .red, by: 0.5))
                    row(icon: "flame", header: "Total Energy", body: "\(metrics.totalEnergy.formatted(.number.precision(.fractionLength(0)))) Cal")
                        .foregroundStyle(.orange.mix(with: .yellow, by: 0.25))
                } else {
                    Text("Unable to load metrics")
                }
                Button("Continue", action: onContinue)
                    .padding(.top, 8)
            }.padding([.leading, .trailing])
                .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    private func row(icon: String, header: String, body: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 24)
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

#Preview {
    WorkoutSummaryView(
        metrics: WorkoutMetrics(state: .ended, startDate: .now, elapsedTime: 754, heartRate: 128, activeEnergy: 210, totalEnergy: 265),
        onContinue: {}
    )
}
