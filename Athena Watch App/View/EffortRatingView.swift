//
//  EffortRatingView.swift
//  Athena Watch App
//
//  Created by Zach Wassynger on 10/1/26.
//

import SwiftUI

/// Post-workout effort rating, shown right after a Functional Strength Training workout
/// ends - matching the native Workout app's 1...10 Digital Crown rating and band colors.
struct EffortRatingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workoutManager = WorkoutManager.shared

    /// Nil until either an estimate loads or the Crown moves. Done stays disabled until
    /// then, so a rating is never saved by accident.
    @State private var score: Double?
    @State private var isEstimated = false

    private var band: (name: String, color: Color)? {
        guard let score else { return nil }
        switch score {
        case ..<4: return ("Easy", .green)
        case ..<7: return ("Moderate", .yellow)
        case ..<9: return ("Hard", .orange)
        default: return ("All Out", .red)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Effort")
                .font(.headline)
            if let score, let band {
                Text(band.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(band.color)
                Text("\(Int(score.rounded()))")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                if isEstimated {
                    Text("Estimated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                segmentBar(filled: Int(score.rounded()))
            } else {
                Text("Turn the Crown to rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                segmentBar(filled: 0)
            }
            HStack {
                Button("Skip") {
                    dismiss()
                }
                Button("Done") {
                    if let score {
                        Task {
                            await workoutManager.saveEffort(Int(score.rounded()))
                            dismiss()
                        }
                    }
                }
                .disabled(score == nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .focusable()
        .digitalCrownRotation(
            Binding(get: { score ?? 0 }, set: { newValue in
                score = newValue
                isEstimated = false
            }),
            from: 1, through: 10, by: 1,
            sensitivity: .medium,
            isContinuous: false
        )
        .task {
            if let estimate = await workoutManager.estimatedEffortScore() {
                score = Double(estimate)
                isEstimated = true
            }
        }
    }

    @ViewBuilder
    private func segmentBar(filled: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index <= filled ? (band?.color ?? .white) : Color.white.opacity(0.2))
                    .frame(height: 6)
            }
        }
    }
}

#Preview {
    EffortRatingView()
}
