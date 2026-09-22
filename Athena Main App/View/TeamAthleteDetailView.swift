//
//  TeamAthleteDetailView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import SwiftUI

/// Athlete-first transpose of `TeamExerciseDetailView`: one athlete's whole team-session
/// entry, grouped by set the same way a solo session's summary is. Deliberately not
/// `RoutineSessionView` — its active-session home page offers a "Finish Session" button
/// that would end this one athlete's entry out from under the parent `TeamSession`.
struct TeamAthleteDetailView: View {
    let entry: Session

    private struct ExerciseLocation: Identifiable {
        let setIndex: Int
        let exerciseIndex: Int
        var id: String { "\(setIndex)-\(exerciseIndex)" }
    }

    @State private var editing: ExerciseLocation? = nil

    var body: some View {
        List {
            ForEach(entry.sets.indices, id: \.self) { setIndex in
                Section(entry.sets[setIndex].name) {
                    ForEach(entry.sets[setIndex].exercises.indices, id: \.self) { exerciseIndex in
                        Button {
                            editing = ExerciseLocation(setIndex: setIndex, exerciseIndex: exerciseIndex)
                        } label: {
                            SessionExerciseEntryView(exercise: entry.sets[setIndex].exercises[exerciseIndex])
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }.navigationTitle(entry.athleteDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { location in
                SessionExerciseSheet(
                    exercise: Binding(
                        get: { entry.sets[location.setIndex].exercises[location.exerciseIndex] },
                        set: { entry.sets[location.setIndex].exercises[location.exerciseIndex] = $0 }
                    ),
                    showing: Binding(
                        get: { editing != nil },
                        set: { newValue in
                            if !newValue {
                                editing = nil
                            }
                        }
                    ),
                    showData: true
                )
            }
    }
}
