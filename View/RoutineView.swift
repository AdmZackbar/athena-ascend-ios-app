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
    let groupedData: [String : [RepWeightChart.Data]]
    @State private var selectedType: String? = nil
    
    init(routine: Routine) {
        self.routine = routine
        self.groupedData = {
            let taggedData: [(String, RepWeightChart.Data)] = routine.sessions.sorted(by: { $0.startTime < $1.startTime }).flatMap({ session in
                session.sets.flatMap({ set in
                    set.exercises.flatMap({ exercise in
                        switch exercise {
                        case .repeater(let d):
                            return d.actual.map({ (
                                RepeaterChartType(tag: d.expected.tag, timeOn: d.expected.timeOn, timeOff: d.expected.timeOff).text,
                                RepWeightChart.Data(date: session.startTime, reps: $0.numReps, weight: $0.weight)
                            ) })
                        case .generic(let d):
                            switch d.expected.dataType {
                            case .repWeight:
                                // TODO L/R
                                return d.actual.map({ (
                                    d.expected.name,
                                    RepWeightChart.Data(date: session.startTime, reps: $0.repsLeft, weight: $0.weightLeft)
                                ) })
                            default:
                                return []
                            }
                        default: return []
                        }
                    })
                })
            })
            let dict = Dictionary(grouping: taggedData) { $0.0 }
            return dict.mapValues({ $0.map({ $0.1 }) })
        }()
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
                            let sessionExercises: [(Session, Session.Exercise)] = routine.sessions.sorted(by: { $0.startTime > $1.startTime }).map({ ($0, $0.sets[setIndex].exercises[exerciseIndex]) })
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
                selectedType = groupedData.keys.sorted().first
            }
    }
    
    struct RepeaterChartType: Hashable, Equatable {
        var tag: String
        var timeOn: Int
        var timeOff: Int
        
        var text: String {
            "\(tag) \(timeOn)s/\(timeOff)s"
        }
    }
    
    @ViewBuilder
    func chartsView() -> some View {
        if !groupedData.isEmpty {
            Section("Charts") {
                Picker("Repeater Type", selection: $selectedType) {
                    ForEach(groupedData.keys.sorted(), id: \.self) {
                        Text($0).tag($0)
                    }
                }
                if let selectedType {
                    RepWeightChart(data: groupedData[selectedType]!)
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
                    HStack {
                        Text(d.main.moves.text)
                        if let alt = d.alt?.moves {
                            Text(alt.text)
                        }
                    }
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

#Preview(traits: .modifier(TestDataModifier())) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineView(routine: routines.first!)
    }
}
