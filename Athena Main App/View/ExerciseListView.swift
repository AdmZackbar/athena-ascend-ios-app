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
            let filtered = exercises.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
                .filter { selectedType.hasType($0) }
                .sorted(by: { $0.name < $1.name })
            Section {
                if !filtered.isEmpty {
                    ForEach(filtered) { exercise in
                        Button {
                            navigationStore.push(ViewType.exercise(exercise: exercise))
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
        }.navigationTitle("View All Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ExerciseListView()
    }
}
