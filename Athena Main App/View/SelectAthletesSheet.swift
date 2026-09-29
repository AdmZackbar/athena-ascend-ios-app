//
//  SelectAthletesSheet.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftData
import SwiftUI

struct SelectAthletesSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    
    let initialSelection: [Athlete]
    let onComplete: ([Athlete]) -> Void
    // Keep this ordered
    @State var selection: [Athlete]
    
    init(initialSelection: [Athlete] = [], onComplete: @escaping ([Athlete]) -> Void) {
        self.initialSelection = initialSelection
        self.onComplete = onComplete
        self.selection = initialSelection
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Selection") {
                    ForEach(selection.enumerated(), id: \.offset) { offset, athlete in
                        Button {
                            selection.remove(at: offset)
                        } label: {
                            athleteView(athlete, selected: true)
                        }.buttonStyle(.plain)
                    }
                }
                let notSelected = athletes.filter { !selection.contains($0) }
                if !notSelected.isEmpty {
                    Section("Roster") {
                        ForEach(notSelected) { athlete in
                            Button {
                                // Keep sorted
                                if let first = selection.firstIndex(where: { $0.name > athlete.name }) {
                                    selection.insert(athlete, at: first)
                                } else {
                                    selection.append(athlete)
                                }
                            } label: {
                                athleteView(athlete, selected: false)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.navigationTitle("Select Athlete(s)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            onComplete(selection)
                            dismiss()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }.disabled(selection.isEmpty || selection == initialSelection)
                    }
                }
        }.presentationDetents([.large])
    }
    
    @ViewBuilder
    func athleteView(_ athlete: Athlete, selected: Bool) -> some View {
        HStack {
            Label(athlete.fullName ?? athlete.name, systemImage: selected ? "checkmark.circle" : "circle")
                .bold(selected && !initialSelection.contains(athlete))
                .strikethrough(!selected && initialSelection.contains(athlete))
            Spacer()
        }.contentShape(Rectangle())
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Athlete.name) var athletes: [Athlete]
    SelectAthletesSheet(initialSelection: [athletes.first!]) { selection in
        // TODO
    }
}
