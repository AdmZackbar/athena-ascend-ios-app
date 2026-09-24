//
//  ExerciseView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

struct ExerciseView: View {
    @State var exercise: Exercise
    @State var athlete: Athlete
    
    var body: some View {
        let data: [(Session, Session.Exercise)] = athlete.sessions
            .flatMap(toSessionSets)
            .filter({ $0.1.exerciseID == exercise.uuid })
            .sorted(by: { $0.0.startTime > $1.0.startTime })
        Form {
            Section(exercise.name) {
                ForEach(data.enumerated(), id: \.offset) { offset, pair in
                    VStack(alignment: .leading) {
                        Text(pair.0.startTime.formatted(date: .abbreviated, time: .omitted))
                            .font(.title3)
                            .fontWeight(.bold)
                        switch pair.1 {
                        case .generic(let d):
                            genericView(d)
                        default:
                            Text("TODO")
                        }
                    }
                }
            }
        }.navigationTitle(athlete.fullName ?? athlete.name)
    }
    
    func toSessionSets(_ session: Session) -> [(Session, Session.Exercise)] {
        return session.sets.flatMap { $0.exercises }.compactMap { (session, $0) }
    }
    
    @ViewBuilder
    func genericView(_ details: Session.GenericData) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16) {
            ForEach(0..<details.expected.sets.count, id: \.self) { idx in
                GridRow(alignment: .top) {
                    Text("Set \(idx + 1)")
                        .fontWeight(.semibold)
                    VStack(alignment: .leading) {
                        if idx < details.actual.count {
                            let actual = details.actual[idx]
                            Text(actual.toString(details.expected))
                            // TODO compare against expected and show if needed
                            if !actual.notes.isEmpty {
                                Text(actual.notes)
                                    .font(.caption)
                                    .italic()
                            }
                        } else {
                            Text(details.expected.sets[idx].text)
                                .italic()
                        }
                    }
                }
            }
        }
        if !details.notes.isEmpty {
            Text(details.notes)
                .font(.subheadline)
                .italic()
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var exercises: [Exercise]
    @Previewable @Query var athletes: [Athlete]
    NavigationStack {
        ExerciseView(exercise: exercises.first!, athlete: athletes.first!)
    }
}
