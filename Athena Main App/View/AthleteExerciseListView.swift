//
//  AthleteExerciseView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftData
import SwiftUI

struct AthleteExerciseListView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    let athlete: Athlete
    
    var body: some View {
        List {
            ForEach(athlete.data.map { $0.exercise }) { exercise in
                Button {
                    navigationStore.push(ViewType.exercise(exercise: exercise, athlete: athlete))
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .font(.headline)
                            Text("\(exercise.data.count) data sets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
}
