//
//  TimerRingView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftUI

/// A ring that drains as `progress` increases, with a label and a count-up/count-down clock
/// in the center. Used for every phase of every exercise kind during a session.
struct TimerRingView: View {
    let text: String
    var textCountDown: Bool = true
    let timerDuration: Duration
    let elapsedSeconds: Duration
    let progress: Double

    var body: some View {
        ZStack {
            RingShape(progress: 1.0)
                .stroke(.secondary, lineWidth: 8)
            RingShape(progress: 1.0 - progress)
                .stroke(.primary, style: .init(lineWidth: 12, lineCap: .round))
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 40))
                    .bold()
                Text(textCountDown ? timerDuration - elapsedSeconds : elapsedSeconds, format: .time(pattern: .minuteSecond(padMinuteToLength: 2)))
                    .contentTransition(.numericText())
                    .monospaced()
                    .font(.system(size: 60))
                    .bold()
            }
        }
    }
}

struct RingShape: Shape {
    var progress: Double // Value from 0.0 to 1.0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: (progress * 360) - 90)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

#Preview {
    TimerRingView(text: "Rest", timerDuration: .seconds(30), elapsedSeconds: .seconds(10), progress: 1.0 / 3.0)
}
