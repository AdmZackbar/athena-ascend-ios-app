//
//  AthleteExerciseView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftUI

struct AthleteExerciseView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    let exercise: Exercise
    let athlete: Athlete
    
    var categoryName: String {
        switch exercise.category {
        case .generic(_, _, _): return "Exercise"
        case .repeater(_, _, _): return "Repeaters"
        case .maxHang(_, _): return "Max Hangs"
        case .campus(_, _): return "Campus Sets"
        }
    }
    
    var body: some View {
        Form {
            ExerciseInfoSection(exercise: exercise)
            Section("Data") {
                let data = athlete.data.filter { $0.exercise == exercise }
                if data.isEmpty {
                    ContentUnavailableView("No data for athlete", systemImage: "tablecells")
                } else {
                    ForEach(data.sorted(by: { $0.session.startTime > $1.session.startTime })) { d in
                        ExerciseDataEntryView(data: d)
                    }
                }
            }
        }.navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        navigationStore.push(ViewType.exerciseEdit(exercise: exercise))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
    }
}
