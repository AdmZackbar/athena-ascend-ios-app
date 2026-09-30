//
//  ExerciseListView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    @Query private var exercises: [Exercise]
    
    @State private var selectedType: SelectExercisesSheet.ExerciseType = .generic
    @State private var filter: String = ""
    
    var body: some View {
        List {
            if !filter.isEmpty {
                exercisesByFilter()
            } else {
                exercisesByType()
            }
        }.navigationTitle("View All Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter)
    }
    
    @ViewBuilder
    func exercisesByFilter() -> some View {
        let filtered = exercises.filter { $0.name.localizedCaseInsensitiveContains(filter) }
            .sorted(by: { $0.name < $1.name })
        if !filtered.isEmpty {
            let byType: [SelectExercisesSheet.ExerciseType: [Exercise]] = .init(grouping: filtered, by: { .from($0.category) })
            ForEach(SelectExercisesSheet.ExerciseType.allCases, id: \.text) { type in
                if let list = byType[type], !list.isEmpty {
                    Section(type.text) {
                        exerciseListView(list)
                    }
                }
            }
        } else {
            // Show placeholders
            exerciseListView([])
        }
    }
    
    @ViewBuilder
    func exercisesByType() -> some View {
        Section {
            exerciseListView(exercises.filter { selectedType == .from($0.category) }
                .sorted(by: { $0.name < $1.name }))
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
    func exerciseListView(_ list: [Exercise]) -> some View {
        if !list.isEmpty {
            ForEach(list) { exercise in
                Button {
                    navigationStore.push(ViewType.exercise(exercise: exercise, selectedAthlete: nil))
                } label: {
                    exerciseView(exercise)
                }.buttonStyle(.plain)
            }
        } else if !exercises.isEmpty {
            ContentUnavailableView("No exercises matching filter(s)", systemImage: "line.3.horizontal.decrease")
        } else {
            ContentUnavailableView("No exercises in DB", systemImage: "tablecells")
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

#Preview(traits: .sampleData) {
    NavigationStack {
        ExerciseListView()
    }
}
