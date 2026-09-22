//
//  TeamExerciseDetailView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import SwiftUI

/// Exercise-first view onto a team session: every athlete's result for one exercise,
/// in one place. This is the primary entry surface — the team does one exercise
/// together, and the coach records each person in turn.
struct TeamExerciseDetailView: View {
    let teamSession: TeamSession
    let setIndex: Int
    let exerciseIndex: Int

    @State private var editingEntry: Session? = nil

    private var exerciseName: String {
        guard exerciseIndex < teamSession.sets[setIndex].exercises.count else { return "" }
        return teamSession.sets[setIndex].exercises[exerciseIndex].name
    }

    var body: some View {
        List {
            ForEach(teamSession.sortedEntries) { entry in
                if exerciseIndex < entry.sets[setIndex].exercises.count {
                    Button {
                        editingEntry = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.athleteDisplayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            SessionExerciseEntryView(exercise: entry.sets[setIndex].exercises[exerciseIndex])
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }.navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingEntry) { entry in
                SessionExerciseSheet(
                    exercise: Binding(
                        get: { entry.sets[setIndex].exercises[exerciseIndex] },
                        set: { entry.sets[setIndex].exercises[exerciseIndex] = $0 }
                    ),
                    showing: Binding(
                        get: { editingEntry != nil },
                        set: { newValue in
                            if !newValue {
                                editingEntry = nil
                            }
                        }
                    ),
                    showData: true
                )
            }
    }
}
