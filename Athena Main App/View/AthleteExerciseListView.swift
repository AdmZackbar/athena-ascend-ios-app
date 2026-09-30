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
            if !filter.isEmpty {
                exercisesByFilter(exercises)
            } else {
                exercisesByType(exercises)
            }
        }.searchable(text: $filter)
    }
    
    @ViewBuilder
    func exercisesByFilter(_ exercises: [Exercise]) -> some View {
        let filtered = exercises.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        if !filtered.isEmpty {
            let byType: [SelectExercisesSheet.ExerciseType: [Exercise]] = .init(grouping: filtered, by: { .from($0.category) })
            ForEach(SelectExercisesSheet.ExerciseType.allCases, id: \.text) { type in
                if let list = byType[type], !list.isEmpty {
                    Section(type.text) {
                        exerciseListView(list, missingExercises: exercises.isEmpty)
                    }
                }
            }
        } else {
            // Show placeholders
            exerciseListView([], missingExercises: exercises.isEmpty)
        }
    }
    
    @ViewBuilder
    func exercisesByType(_ exercises: [Exercise]) -> some View {
        Section {
            exerciseListView(exercises.filter { selectedType == .from($0.category) }, missingExercises: exercises.isEmpty)
        } header: {
            Picker("Exercise Type", selection: $selectedType) {
                ForEach(SelectExercisesSheet.ExerciseType.allCases, id: \.text) { t in
                    Text(t.text).tag(t)
                }
            }.pickerStyle(.segmented)
                .padding([.leading, .trailing], -16)
        }
    }
    
    @ViewBuilder
    func exerciseListView(_ list: [Exercise], missingExercises: Bool) -> some View {
        if !list.isEmpty {
            ForEach(list) { exercise in
                Button {
                    navigationStore.push(ViewType.exercise(exercise: exercise, selectedAthlete: athlete))
                } label: {
                    exerciseView(exercise)
                }.buttonStyle(.plain)
            }
        } else if !missingExercises {
            ContentUnavailableView("No exercises matching filter(s)", systemImage: "line.3.horizontal.decrease")
        } else {
            ContentUnavailableView("No exercises for athlete", systemImage: "person")
        }
    }
    
    @ViewBuilder
    func exerciseView(_ exercise: Exercise) -> some View {
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
    }
}
