//
//  RoutineView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/19/26.
//

import Charts
import SwiftData
import SwiftUI

struct RoutineView: View {
    let routine: Routine
    let groupedData: [ExerciseGroupKey: [RepWeightChart.Data]]
    let groupLabels: [ExerciseGroupKey: String]
    @State private var selectedType: ExerciseGroupKey? = nil

    init(routine: Routine) {
        self.routine = routine

        // Prefer the routine's own current label for anything still prescribed —
        // it's kept fresh by rename propagation. Session-only occurrences (the
        // exercise was later removed from the routine) fall back to whatever label
        // they were recorded under.
        var labels: [ExerciseGroupKey: String] = [:]
        for set in routine.sets {
            for payload in set.exercises {
                if let key = ExerciseGroupKey(payload) {
                    labels[key] = payload.name
                }
            }
        }

        var taggedData: [(ExerciseGroupKey, RepWeightChart.Data)] = []
        for session in routine.sessions.sorted(by: { $0.startTime < $1.startTime }) {
            for set in session.sets {
                for payload in set.exercises {
                    guard let key = ExerciseGroupKey(payload) else { continue }
                    if labels[key] == nil {
                        labels[key] = payload.name
                    }
                    switch payload {
                    case .repeater(let d):
                        taggedData.append(contentsOf: d.actual.map({ (
                            key,
                            RepWeightChart.Data(date: session.startTime, reps: $0.numReps, weight: $0.weight)
                        ) }))
                    case .generic(let d):
                        switch d.expected.dataType {
                        case .repWeight:
                            // TODO L/R
                            taggedData.append(contentsOf: d.actual.map({ (
                                key,
                                RepWeightChart.Data(date: session.startTime, reps: $0.repsLeft, weight: $0.weightLeft)
                            ) }))
                        default:
                            break
                        }
                    default:
                        break
                    }
                }
            }
        }

        self.groupLabels = labels
        let dict = Dictionary(grouping: taggedData, by: { $0.0 })
        self.groupedData = dict.mapValues({ $0.map({ $0.1 }) })
    }

    private var sortedGroupKeys: [ExerciseGroupKey] {
        groupedData.keys.sorted { (groupLabels[$0] ?? "") < (groupLabels[$1] ?? "") }
    }

    var body: some View {
        Form {
            chartsView()
            ForEach(routine.sets.enumerated(), id: \.offset) { offset, set in
                let setIndex = offset
                Section(set.name) {
                    ForEach(set.exercises.enumerated(), id: \.offset) { offset, exercise in
                        let exerciseIndex = offset
                        VStack(alignment: .leading) {
                            headerView(exercise)
                            let sessionExercises: [(Session, Session.Exercise)] = routine.sessions
                                .sorted(by: { $0.startTime > $1.startTime })
                                .compactMap { session in
                                    if let exerciseID = exercise.exerciseID,
                                       let match = session.sets.flatMap(\.exercises).first(where: { $0.exerciseID == exerciseID }) {
                                        return (session, match)
                                    }
                                    // Pre-V2 data or a race between migration and a
                                    // session's first save: fall back to a
                                    // bounds-checked positional read rather than the
                                    // unguarded index that used to trap here.
                                    guard setIndex < session.sets.count,
                                          exerciseIndex < session.sets[setIndex].exercises.count else {
                                        return nil
                                    }
                                    return (session, session.sets[setIndex].exercises[exerciseIndex])
                                }
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 16) {
                                    expectedDataView(exercise: exercise)
                                    ForEach(sessionExercises.enumerated(), id: \.offset) { offset, s in
                                        sessionExerciseView(session: s.0, expected: exercise, actual: s.1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }.navigationTitle(routine.name)
            .onAppear {
                selectedType = sortedGroupKeys.first
            }
    }

    @ViewBuilder
    func chartsView() -> some View {
        if !groupedData.isEmpty {
            Section("Charts") {
                Picker("Exercise", selection: $selectedType) {
                    ForEach(sortedGroupKeys, id: \.self) { key in
                        Text(groupLabels[key] ?? "Unknown").tag(key as ExerciseGroupKey?)
                    }
                }
                if let selectedType, let data = groupedData[selectedType] {
                    RepWeightChart(data: data)
                }
            }
        }
    }
    
    @ViewBuilder
    func headerView(_ exercise: Routine.Exercise) -> some View {
        switch exercise {
        case .generic(let d):
            Text(d.name)
                .font(.headline)
                .bold()
        case .repeater(let d):
            Text("Repeater")
                .font(.subheadline)
                .italic()
            Text("\(d.tag) \(d.timeOn)s/\(d.timeOff)s")
                .font(.headline)
                .bold()
        case .maxHang(let d):
            Text("Max Hang")
                .font(.subheadline)
                .italic()
            Text(d.tag)
                .font(.headline)
                .bold()
        case .campus(let d):
            Text("Campus")
                .font(.subheadline)
                .italic()
            Text(d.type.text)
                .font(.headline)
                .bold()
        }
    }
    
    @ViewBuilder
    func sessionExerciseView(session: Session, expected: Routine.Exercise, actual: Session.Exercise) -> some View {
        VStack(alignment: .leading) {
            Text(session.startTime.formatted(date: .numeric, time: .omitted))
                .bold()
            if !actual.isBasedOn(expected) {
                let updated: String = {
                    switch actual {
                    case .generic(let d):
                        return d.expected.name
                    case .repeater(let d):
                        return "\(d.expected.tag) \(d.expected.timeOn)s/\(d.expected.timeOff)s"
                    case .maxHang(let d):
                        return d.expected.tag
                    case .campus(let d):
                        return d.expected.type.text
                    }
                }()
                Text(updated)
                    .fontWeight(.semibold)
            }
            switch actual {
            case .generic(let data):
                ForEach(data.actual.enumerated(), id: \.offset) { offset, d in
                    Text(d.toString(data.expected))
                }
            case .repeater(let data):
                ForEach(data.actual.enumerated(), id: \.offset) { offset, d in
                    Text(d.text)
                }
            case .maxHang(let data):
                ForEach(data.actual.enumerated(), id: \.offset) { offset, d in
                    Text(d.text)
                }
            case .campus(let data):
                ForEach(data.actual.enumerated(), id: \.offset) { offset, d in
                    Text(d.text)
                }
            }
        }.font(.subheadline)
    }
    
    @ViewBuilder
    func expectedDataView(exercise: Routine.Exercise) -> some View {
        VStack(alignment: .leading) {
            Text("Expected")
                .bold()
                .italic(false)
            switch exercise {
            case .generic(let data):
                ForEach(data.sets.enumerated(), id: \.offset) { offset, set in
                    Text("\(set.text) \(data.setDetailText)")
                }
            case .repeater(let data):
                ForEach(data.sets.enumerated(), id: \.offset) { offset, set in
                    Text(set.text)
                }
            case .maxHang(let data):
                ForEach(data.sets.enumerated(), id: \.offset) { offset, set in
                    Text(set.text)
                }
            case .campus(let data):
                ForEach(data.sets.enumerated(), id: \.offset) { offset, set in
                    Text(set.text)
                }
            }
        }.font(.subheadline)
            .italic()
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineView(routine: routines.first!)
    }
}
