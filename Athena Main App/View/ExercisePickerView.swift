//
//  ExercisePickerView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import SwiftData
import SwiftUI

/// A library entry pickable via `LibraryPickerView` — anything with a display name and
/// a "last used" recency signal to sort/browse by.
protocol LibraryEntry: PersistentModel {
    var name: String { get }
    var lastUsedAt: Date? { get set }
}

extension Exercise: LibraryEntry {}
extension Athlete: LibraryEntry {}

/// Lets the user pick an existing library entry rather than starting from scratch.
/// `T == Exercise` fetches every kind polymorphically (the unfiltered "From Library…"
/// flow); a concrete subclass like `T == RepeaterExercise` narrows to just that kind.
/// `T == Athlete` reuses the same list/search/recency UI for the athlete roster.
struct LibraryPickerView<T: LibraryEntry>: View {
    @Query private var entries: [T]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    let title: String
    let emptyText: String
    let exclude: (T) -> Bool
    let onPick: (T) -> Void

    /// - Parameter exclude: Entries for which this returns true are left off the list —
    ///   used by the library's "Merge into…" flow to hide the entry being merged away.
    init(title: String = "Choose Exercise", emptyText: String = "No exercises yet", exclude: @escaping (T) -> Bool = { _ in false }, onPick: @escaping (T) -> Void) {
        self._entries = Query(sort: [
            SortDescriptor(\T.lastUsedAt, order: .reverse),
            SortDescriptor(\T.name)
        ])
        self.title = title
        self.emptyText = emptyText
        self.exclude = exclude
        self.onPick = onPick
    }

    private var filteredEntries: [T] {
        let base = entries.filter { !exclude($0) }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredEntries.isEmpty {
                    Text(entries.isEmpty ? emptyText : "No matches")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredEntries) { entry in
                    Button {
                        // Deliberately don't call `dismiss()` here: callers are
                        // presenting this view via a shared sheet-item binding and
                        // reassign that same binding inside `onPick` to chain straight
                        // into a follow-up sheet. Calling dismiss() too would race
                        // with that reassignment and could null it back out.
                        onPick(entry)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.name)
                                .fontWeight(.semibold)
                            if let lastUsedAt = entry.lastUsedAt {
                                Text("Last used \(lastUsedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.navigationTitle(title)
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
