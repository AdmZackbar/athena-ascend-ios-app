//
//  RepeaterOverview.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/20/26.
//

import SwiftData
import SwiftUI

struct RepeaterOverview: View {
    let athlete: Athlete
    @Query(sort: \Session.startTime, order: .reverse) private var allSessions: [Session]

    /// This athlete's full history, solo sessions and team-session entries alike —
    /// unlike the routine-scoped views, there's no reason to exclude team data here:
    /// it's all this person's own numbers.
    private var sessions: [Session] {
        allSessions.filter { $0.athlete?.uuid == athlete.uuid }
    }

    // Grouped by the exercise's stable library ID (falling back to the derived
    // identity for anything that predates the library), so a rename no longer
    // splits a repeater's history in two the way grouping by raw tag once did.
    private var groupedRepeaters: (labels: [ExerciseGroupKey: String], map: [ExerciseGroupKey: [(Session, Session.RepeaterData)]]) {
        let tagged: [(ExerciseGroupKey, Session, Session.RepeaterData)] = sessions.flatMap { session in
            session.sets.flatMap(\.exercises).compactMap { exercise -> (ExerciseGroupKey, Session, Session.RepeaterData)? in
                guard case .repeater(let d) = exercise, let key = ExerciseGroupKey(exercise) else { return nil }
                return (key, session, d)
            }
        }
        var labels: [ExerciseGroupKey: String] = [:]
        for (key, _, d) in tagged where labels[key] == nil {
            labels[key] = "\(d.expected.tag) \(d.expected.timeOn)s/\(d.expected.timeOff)s"
        }
        let map: [ExerciseGroupKey: [(Session, Session.RepeaterData)]] = Dictionary(grouping: tagged, by: { $0.0 })
            .mapValues({ $0.map({ ($0.1, $0.2) }) })
        return (labels, map)
    }

    var body: some View {
        let grouped = groupedRepeaters
        Form {
            ForEach(grouped.map.sorted(by: { (grouped.labels[$0.key] ?? "") < (grouped.labels[$1.key] ?? "") }), id: \.key) { key, pairs in
                Section(grouped.labels[key] ?? "Unknown") {
                    ForEach(pairs.enumerated(), id: \.offset) { offset, pair in
                        VStack(alignment: .leading) {
                            let session = pair.0
                            let data = pair.1
                            Text(session.startTime.formatted(date: .numeric, time: .shortened))
                                .bold()
                            VStack(alignment: .leading) {
                                ForEach(data.actual.enumerated(), id: \.offset) { offset, set in
                                    Text(set.text)
                                }
                            }.font(.subheadline)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
        }.navigationTitle("All Repeaters")
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    NavigationStack {
        RepeaterOverview(athlete: athletes.first!)
    }
}
