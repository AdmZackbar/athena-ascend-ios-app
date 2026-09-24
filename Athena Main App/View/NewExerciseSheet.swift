//
//  NewExerciseSheet.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import SwiftData
import SwiftUI

/// Creates a new exercise library entry, independent of any routine or session. The
/// segmented Kind picker lets the user change kind mid-entry without backing out of the
/// sheet; the fields below swap to match.
struct NewExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Identities already in the library, supplied by the caller so this view doesn't
    /// need its own `@Query` — `ExerciseLibraryView` already has the list fetched.
    let existingIdentities: [ExerciseIdentity]
    let onCreate: (Exercise) -> Void

    @State private var draft = Draft()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    fields
                } header: {
                    Picker("", selection: $draft.kind) {
                        ForEach(Draft.Kind.allCases, id: \.name) { kind in
                            Text(kind.name).tag(kind)
                        }
                    }.pickerStyle(.segmented)
                } footer: {
                    if isDuplicate {
                        Text("An exercise with this configuration already exists.")
                    } else if draft.kind == .campus {
                        Text("Name is derived from the campus type.")
                    }
                }
            }.navigationTitle("New Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            save()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }.disabled(draft.identity == nil || isDuplicate)
                    }
                }
        }.presentationDetents([.medium, .large])
    }

    private var isDuplicate: Bool {
        guard let identity = draft.identity else { return false }
        return ExerciseLibrary.isDuplicate(identity, among: existingIdentities)
    }

    private func save() {
        guard let identity = draft.identity, !isDuplicate else { return }
        let exercise = ExerciseLibrary.findOrCreate(for: identity, in: modelContext)
        onCreate(exercise)
        dismiss()
    }

    @ViewBuilder
    private var fields: some View {
        switch draft.kind {
        case .basic:
            TextField("Name", text: $draft.name)
            Picker("Type", selection: $draft.dataType) {
                ForEach(Routine.GenericSets.DataType.allCases, id: \.name) { type in
                    Text(type.name).tag(type)
                }
            }
            Picker("Sided-ness", selection: $draft.sideType) {
                Text("None").tag(nil as Routine.SideType?)
                ForEach(Routine.SideType.allCases, id: \.name) { type in
                    Text(type.name).tag(type as Routine.SideType?)
                }
            }
        case .repeater:
            TextField("Tag", text: $draft.name)
            Stepper("On: \(draft.timeOn)s", value: $draft.timeOn, in: 0...30)
            Stepper("Off: \(draft.timeOff)s", value: $draft.timeOff, in: 0...30)
        case .maxHang:
            TextField("Tag", text: $draft.name)
            Toggle("Independent Sides", isOn: $draft.isSingleArm)
        case .campus:
            Picker("Type", selection: $draft.campusType) {
                ForEach(Routine.CampusSets.Exercise.allCases, id: \.text) { type in
                    Text(type.text).tag(type)
                }
            }
        }
    }

    private struct Draft {
        enum Kind: CaseIterable, Hashable {
            case basic, repeater, maxHang, campus

            var name: String {
                switch self {
                case .basic: "Basic"
                case .repeater: "Repeater"
                case .maxHang: "Max Hang"
                case .campus: "Campus"
                }
            }
        }

        var kind: Kind = .basic
        var name: String = ""
        var dataType: Routine.GenericSets.DataType = .repWeight
        var sideType: Routine.SideType? = nil
        var timeOn: Int = 7
        var timeOff: Int = 3
        var isSingleArm: Bool = true
        var campusType: Routine.CampusSets.Exercise = .maxLadder

        /// Nil when the free-text name is empty for the three named kinds. Campus has
        /// no free-text field, so it's always non-nil.
        var identity: ExerciseIdentity? {
            switch kind {
            case .basic:
                guard !name.isEmpty else { return nil }
                return .generic(name: name, dataType: dataType, sideType: sideType)
            case .repeater:
                guard !name.isEmpty else { return nil }
                return .repeater(tag: name, timeOn: timeOn, timeOff: timeOff)
            case .maxHang:
                guard !name.isEmpty else { return nil }
                return .maxHang(tag: name, isSingleArm: isSingleArm)
            case .campus:
                return .campus(campusType)
            }
        }
    }
}

#Preview(traits: .sampleData) {
    NewExerciseSheet(existingIdentities: []) { _ in }
}
