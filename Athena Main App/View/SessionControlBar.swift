//
//  SessionControlBar.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftUI

/// The prev/toggle-timer/next control row shown beneath every exercise phase during a session.
struct SessionControlBar: View {
    let isTimerRunning: Bool
    let allowTimerNext: Bool
    let elapsedSeconds: Duration
    let timerDuration: Duration
    let onPrev: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            Button(action: onPrev) {
                Image(systemName: "arrowshape.backward.circle")
                    .font(.system(size: 64))
            }
            Button(action: onToggle) {
                Image(systemName: isTimerRunning ? "pause.circle" : "play.circle")
                    .font(.system(size: 96))
            }.disabled(elapsedSeconds >= timerDuration)
            Button(action: onNext) {
                Image(systemName: allowTimerNext || elapsedSeconds >= timerDuration ? "arrowshape.forward.circle" : "checkmark.circle")
                    .font(.system(size: 64))
            }
            Spacer()
        }.buttonStyle(.plain)
    }
}

#Preview {
    SessionControlBar(isTimerRunning: true, allowTimerNext: true, elapsedSeconds: .seconds(10), timerDuration: .seconds(30), onPrev: {}, onToggle: {}, onNext: {})
}
