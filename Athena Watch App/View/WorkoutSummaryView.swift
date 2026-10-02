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
        VStack(spacing: 8) {
            Text("Workout Saved")
                .font(.headline)
            if let metrics {
                Text("\(Int(metrics.elapsedTime)) sec")
                Text("\(Int(metrics.activeEnergy)) kcal active")
                Text("\(Int(metrics.totalEnergy)) kcal total")
                if let heartRate = metrics.heartRate {
                    Text("\(Int(heartRate)) bpm")
                }
            }
            Button("Continue", action: onContinue)
        }
        .padding()
    }
}

#Preview {
    WorkoutSummaryView(
        metrics: WorkoutMetrics(state: .ended, startDate: .now, elapsedTime: 754, heartRate: 128, activeEnergy: 210, totalEnergy: 265),
        onContinue: {}
    )
}
