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
    
    @State private var selectedType: SelectExercisesSheet.ExerciseType = .generic
    @State private var filter: String = ""
    
    var body: some View {
        let exercises = Set(athlete.data.map { $0.exercise }).sorted(by: { $0.name < $1.name })
        List {
            let filtered = exercises.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
                .filter { selectedType.hasType($0) }
            Section {
                if !filtered.isEmpty {
                    ForEach(filtered) { exercise in
                        Button {
                            navigationStore.push(ViewType.exercise(exercise: exercise, athlete: athlete))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text("\(exercise.data.filter({ $0.athlete == athlete }).count) data sets")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                } else if !exercises.isEmpty {
                    ContentUnavailableView("No exercises matching filter(s)", systemImage: "line.3.horizontal.decrease")
                } else {
                    ContentUnavailableView("No exercises for athlete", systemImage: "person")
                }
            } header: {
                Picker("Type", selection: $selectedType) {
                    ForEach(SelectExercisesSheet.ExerciseType.allCases, id: \.text) { type in
                        Text(type.text).tag(type)
                    }
                }.pickerStyle(.segmented)
                    .padding([.leading, .trailing], -16)
            }
        }.searchable(text: $filter)
    }
}
