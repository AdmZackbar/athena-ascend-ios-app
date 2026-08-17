//
//  RoutineSessionView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftData
import SwiftUI
internal import Combine

struct RoutineSessionView: View {
    let activeColor = Color("ActiveColor")
    let readyColor = Color("ReadyColor")
    let restColor = Color("RestColor")
    
    let routine: Routine
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    @State private var state: SessionState = .start
    @State private var time: Int = 0
    @State private var timeFraction: Int = 0
    @State private var rep: Int = 0
    @State private var active: Bool = false
    
    init(routine: Routine) {
        self.routine = routine
    }
    
    var body: some View {
        mainView()
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(state == .start ? .automatic : .inline)
            .background(computeBackground())
            .onReceive(timer) { t in
                if time > 0 || timeFraction > 0 {
                    guard active else { return }
                    if timeFraction > 0 {
                        timeFraction -= 1
                    } else {
                        time -= 1
                        timeFraction = 9
                    }
                } else {
                    // Only auto go to next for these states
                    switch state {
                    case .ready(_, _), .active(_, _):
                        nextState()
                    default:
                        break
                    }
                }
            }
    }
    
    func nextState() {
        switch state {
        case .start:
            state = .set(index: 0)
        case .set(let index):
            readyTimer()
            state = .ready(setIndex: index, exerciseIndex: 0)
        case .ready(let setIndex, let exerciseIndex):
            let exercise = routine.sets[setIndex].exercises[exerciseIndex]
            switch exercise {
            case .repeater(let r):
                rep = (r.numReps - 1) * 2
                time = r.timeOn
            case .maxHang(let m):
                rep = 0
                // TODO allow for target overshoot
                time = m.target
            }
            state = .active(setIndex: setIndex, exerciseIndex: exerciseIndex)
        case .active(let setIndex, let exerciseIndex):
            if rep > 0 {
                rep -= 1
                let exercise = routine.sets[setIndex].exercises[exerciseIndex]
                switch exercise {
                case .repeater(let r):
                    time = rep % 2 == 0 ? r.timeOn : r.timeOff
                case .maxHang(let r):
                    time = r.target
                }
            } else {
                time = routine.sets[setIndex].restTime
                state = .record(setIndex: setIndex, exerciseIndex: exerciseIndex)
            }
        case .record(let setIndex, let exerciseIndex):
            readyTimer()
            if exerciseIndex >= routine.sets[setIndex].exercises.count - 1 {
                if setIndex >= routine.sets.count - 1 {
                    state = .finish
                } else {
                    state = .set(index: setIndex + 1)
                }
            } else {
                state = .ready(setIndex: setIndex, exerciseIndex: exerciseIndex + 1)
            }
        case .finish:
            break
        }
    }
    
    func computeBackground() -> some ShapeStyle {
        switch state {
        case .ready(_, _):
            return readyColor
        case .active(let setIndex, let exerciseIndex):
            switch routine.sets[setIndex].exercises[exerciseIndex] {
            case .repeater(_):
                return rep % 2 == 0 ? activeColor : readyColor
            default:
                return activeColor
            }
        case .record(_, _):
            return restColor
        default:
            return Color(uiColor: .systemGroupedBackground)
        }
    }
    
    @ViewBuilder
    func mainView() -> some View {
        switch state {
        case .start:
            landingPage()
        case .set(let index):
            setView(index: index)
        case .ready(let setIndex, let exerciseIndex):
            restView(setIndex: setIndex, exerciseIndex: exerciseIndex)
        case .active(let setIndex, let exerciseIndex):
            activeView(setIndex: setIndex, exerciseIndex: exerciseIndex)
        case .record(let setIndex, let exerciseIndex):
            recordView(setIndex: setIndex, exerciseIndex: exerciseIndex)
        case .finish:
            // TODO
            ZStack {
                Text("Finished!")
            }
        }
    }
    
    @ViewBuilder
    func landingPage() -> some View {
        if !routine.sets.isEmpty {
            setView(index: 0)
        } else {
            Text("No Sets!")
        }
    }
    
    @ViewBuilder
    func setView(index: Int) -> some View {
        let set = routine.sets[index]
        VStack {
            Form {
                Section("Set \(index + 1)/\(routine.sets.count): \(set.name)") {
                    ForEach(set.exercises, id: \.hashValue) { exercise in
                        Text(exercise.description)
                    }
                }
            }
            Button("Start") {
                readyTimer()
                state = .ready(setIndex: index, exerciseIndex: 0)
            }.disabled(set.exercises.isEmpty)
        }
    }
    
    @ViewBuilder
    func restView(setIndex: Int, exerciseIndex: Int) -> some View {
        let exercise = routine.sets[setIndex].exercises[exerciseIndex]
        VStack(alignment: .center) {
            Text("Get Ready")
            Text(formatTimer())
            Text(exercise.description)
            Spacer()
            controlView(setIndex: setIndex, exerciseIndex: exerciseIndex)
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func activeView(setIndex: Int, exerciseIndex: Int) -> some View {
        let exercise = routine.sets[setIndex].exercises[exerciseIndex]
        VStack {
            switch exercise {
            case .repeater(let r):
                repeaterView(r)
            case .maxHang(_):
                ZStack {
                    Text("TODO")
                }
            }
            Spacer()
            controlView(setIndex: setIndex, exerciseIndex: exerciseIndex)
        }.padding()
    }
    
    @ViewBuilder
    func repeaterView(_ repeater: Routine.Repeater) -> some View {
        let isOn = rep % 2 == 0
        VStack(alignment: .leading, spacing: 12) {
            Text(repeater.weight == 0 ? repeater.tag : "\(repeater.tag) @ \(repeater.weight.formatted(.number.precision(.fractionLength(0...2))))lb")
                .font(.title)
                .bold()
            HStack {
                Text("Rep")
                Spacer()
                Text("\(repeater.numReps - (rep + 1) / 2)/\(repeater.numReps)")
            }.font(.title2)
                .bold()
            ZStack {
                RingShape(progress: 1.0)
                    .stroke(.secondary, lineWidth: 8)
                let max = Double(isOn ? repeater.timeOn : repeater.timeOff)
                let current = Double(time) + (Double(timeFraction) / 10.0)
                RingShape(progress: (max - current) / max)
                    .stroke(.primary, style: .init(lineWidth: 12, lineCap: .round))
                VStack(spacing: 0) {
                    Text(isOn ? "On" : "Off")
                        .font(.system(size: 48))
                        .bold()
                    Text(formatTimer())
                        .font(.system(size: 60))
                        .bold()
                }
            }
        }.padding()
    }
    
    @ViewBuilder
    func recordView(setIndex: Int, exerciseIndex: Int) -> some View {
        VStack(alignment: .center) {
            Text("Rest")
            Text(formatTimer())
            Text("TODO: record")
            if exerciseIndex < routine.sets[setIndex].exercises.count - 1 {
                let next = routine.sets[setIndex].exercises[exerciseIndex + 1]
                Text("Next: \(next.description)").font(.title2)
            }
            Spacer()
            controlView(setIndex: setIndex, exerciseIndex: exerciseIndex)
        }.font(.title)
            .padding()
    }
    
    @ViewBuilder
    func controlView(setIndex: Int, exerciseIndex: Int) -> some View {
        HStack(spacing: 16) {
            Spacer()
            Button {
                readyTimer()
                state = .ready(setIndex: setIndex, exerciseIndex: exerciseIndex - 1)
            } label: {
                Image(systemName: "arrowshape.backward.circle")
                    .font(.system(size: 64))
            }.disabled(exerciseIndex <= 0)
            Button {
                active.toggle()
            } label: {
                Image(systemName: active ? "pause.circle" : "play.circle")
                    .font(.system(size: 96))
            }
            Button {
                nextState()
            } label: {
                Image(systemName: "arrowshape.forward.circle")
                    .font(.system(size: 64))
            }
            Spacer()
        }.buttonStyle(.plain)
    }
    
    func readyTimer() {
        // TODO 10
        time = 3
        active = true
    }
    
    func formatTimer() -> String {
        let seconds = Double(time)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional // Produces 00:00 format
        formatter.zeroFormattingBehavior = .pad // Adds leading zeros
        if seconds > 30 {
            return formatter.string(from: seconds) ?? "00:00"
        }
        return "\(formatter.string(from: seconds) ?? "00:00").\(timeFraction)"
    }
    
    enum SessionState: Codable, Hashable, Equatable {
        case start
        case set(index: Int)
        case ready(setIndex: Int, exerciseIndex: Int)
        case active(setIndex: Int, exerciseIndex: Int)
        case record(setIndex: Int, exerciseIndex: Int)
        case finish
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

#Preview(traits: .modifier(TestDataModifier())) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineSessionView(routine: routines.first!)
    }
}
