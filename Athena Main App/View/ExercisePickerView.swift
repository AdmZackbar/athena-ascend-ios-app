//
//  ExercisePickerView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import SwiftData
import SwiftUI

/// Lets the user pick an existing library entry rather than starting a new exercise
/// from scratch. `T == Exercise` fetches every kind polymorphically (the unfiltered
/// "From Library…" flow); a concrete subclass like `T == RepeaterExercise` narrows
/// to just that kind.
struct ExercisePickerView<T: Exercise & PersistentModel>: View {
    @Query private var exercises: [T]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    let exclude: (T) -> Bool
    let onPick: (T) -> Void

    /// - Parameter exclude: Entries for which this returns true are left off the list —
    ///   used by the library's "Merge into…" flow to hide the entry being merged away.
    init(exclude: @escaping (T) -> Bool = { _ in false }, onPick: @escaping (T) -> Void) {
        self._exercises = Query(sort: [
            SortDescriptor(\T.lastUsedAt, order: .reverse),
            SortDescriptor(\T.name)
        ])
        self.exclude = exclude
        self.onPick = onPick
    }

    private var filteredExercises: [T] {
        let base = exercises.filter { !exclude($0) }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredExercises.isEmpty {
                    Text(exercises.isEmpty ? "No exercises yet" : "No matches")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredExercises) { exercise in
                    Button {
                        // Deliberately don't call `dismiss()` here: callers are
                        // presenting this view via a shared sheet-item binding and
                        // reassign that same binding inside `onPick` to chain straight
                        // into a follow-up sheet. Calling dismiss() too would race
                        // with that reassignment and could null it back out.
                        onPick(exercise)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .fontWeight(.semibold)
                            if let lastUsedAt = exercise.lastUsedAt {
                                Text("Last used \(lastUsedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.navigationTitle("Choose Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                }
        }
    }
}
