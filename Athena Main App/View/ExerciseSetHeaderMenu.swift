//
//  ExerciseSetHeaderMenu.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import SwiftUI

/// The "From Library... / New ▸ / Delete Set" options menu shown in a set's header, shared by
/// `SessionHomeView` (single-athlete sessions) and `TeamSessionView` (team sessions). The two
/// callers mutate their sets differently, so this only carries the menu structure.
struct ExerciseSetHeaderMenu: View {
    let onPickFromLibrary: () -> Void
    let onAddNew: (Session.Exercise) -> Void
    let onDeleteSet: () -> Void

    var body: some View {
        Menu {
            Button("From Library...", action: onPickFromLibrary)
            Menu {
                Button("Basic") {
                    onAddNew(.generic(.init(expected: .init())))
                }
                Button("Repeater") {
                    onAddNew(.repeater(.init(expected: .init())))
                }
                Button("Max Hang") {
                    onAddNew(.maxHang(.init(expected: .init())))
                }
                Button("Campus") {
                    onAddNew(.campus(.init(expected: .init())))
                }
            } label: {
                Label("New", systemImage: "plus")
            }
            Divider()
            Button(role: .destructive, action: onDeleteSet) {
                Label("Delete Set", systemImage: "trash")
            }
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
    }
}

/// The start/end date editing form shared by `RoutineSessionView` and `TeamSessionView`.
struct SessionDateSheet: View {
    @Binding var start: Date
    @Binding var end: Date?

    var body: some View {
        Form {
            DatePicker("Start:", selection: $start, displayedComponents: [.date, .hourAndMinute])
            DatePicker("End:", selection: .init(get: {
                end ?? .now
            }, set: { newValue in
                end = newValue
            }), displayedComponents: [.date, .hourAndMinute])
        }.presentationDetents([.medium])
    }
}
