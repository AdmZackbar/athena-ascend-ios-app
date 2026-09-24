//
//  ExerciseLibraryView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import SwiftData
import SwiftUI

/// Browse, rename, merge, and delete the exercises trained across every routine and
/// session.
struct ExerciseLibraryView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [
        SortDescriptor(\Exercise.lastUsedAt, order: .reverse),
        SortDescriptor(\Exercise.name)
    ]) private var exercises: [Exercise]
    @Query private var routines: [Routine]
    @Query private var sessions: [Session]

    @State private var renamingExercise: Exercise? = nil
    @State private var renameText: String = ""
    @State private var mergeSource: Exercise? = nil
    @State private var deleteTarget: Exercise? = nil

    var body: some View {
        mainView()
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Rename Exercise", isPresented: .init(get: {
                renamingExercise != nil
            }, set: { newValue in
                if !newValue {
                    renamingExercise = nil
                }
            })) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renamingExercise = nil
                }
                Button("Save") {
                    if let renamingExercise, !renameText.isEmpty {
                        ExerciseLibrary.rename(renamingExercise, to: renameText, routines: routines, sessions: sessions)
                    }
                    renamingExercise = nil
                }
            }
            .sheet(item: $mergeSource) { source in
                mergeTargetPicker(for: source)
            }
            .alert("Delete Exercise?", isPresented: .init(get: {
                deleteTarget != nil
            }, set: { newValue in
                if !newValue {
                    deleteTarget = nil
                }
            })) {
                Button("Cancel", role: .cancel) {
                    deleteTarget = nil
                }
                Button("Delete", role: .destructive) {
                    if let deleteTarget {
                        ExerciseLibrary.clearLinks(to: deleteTarget, routines: routines, sessions: sessions)
                        modelContext.delete(deleteTarget)
                    }
                    deleteTarget = nil
                }
            } message: {
                if let deleteTarget {
                    let usage = ExerciseLibrary.usageCount(of: deleteTarget, routines: routines, sessions: sessions)
                    Text("Used in \(usage.routines) routine(s) and \(usage.sessions) session(s). They'll keep their name and config — they just won't be linked to this entry anymore.")
                }
            }
    }
    
    @ViewBuilder
    func mainView() -> some View {
        if exercises.isEmpty {
            ContentUnavailableView("No Exercises Yet", systemImage: "scalemass")
        } else {
            List {
                ForEach(exercises) { exercise in
                    row(for: exercise)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for exercise: Exercise) -> some View {
        let usage = ExerciseLibrary.usageCount(of: exercise, routines: routines, sessions: sessions)
        Menu {
            // Campus has no free-text field to rewrite — its label is always derived
            // from its campus type — so renaming it wouldn't do anything.
            if !(exercise is CampusLibraryExercise) {
                Button {
                    renameText = exercise.name
                    renamingExercise = exercise
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            Button {
                mergeSource = exercise
            } label: {
                Label("Merge into...", systemImage: "arrow.triangle.merge")
            }
            Divider()
            Button(role: .destructive) {
                deleteTarget = exercise
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .fontWeight(.semibold)
                Text(subtitle(for: exercise))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(usage.routines) routine(s) · \(usage.sessions) session(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func subtitle(for exercise: Exercise) -> String {
        switch exercise {
        case let e as GenericExercise:
            var parts = ["Generic", e.dataType.name]
            if let sideType = e.sideType {
                parts.append(sideType.name)
            }
            return parts.joined(separator: " • ")
        case let e as RepeaterExercise:
            return "Repeater • \(e.timeOn)s/\(e.timeOff)s"
        case let e as MaxHangExercise:
            return "Max Hang • \(e.isSingleArm ? "Independent Sides" : "Combined")"
        case let e as CampusLibraryExercise:
            return "Campus • \(e.campusType.text)"
        default:
            return ""
        }
    }

    /// The merge target picker is typed to the source's own concrete subclass, so
    /// only same-kind entries are ever offered.
    @ViewBuilder
    private func mergeTargetPicker(for source: Exercise) -> some View {
        switch source {
        case is GenericExercise:
            LibraryPickerView<GenericExercise>(exclude: { $0.uuid == source.uuid }) { target in
                ExerciseLibrary.merge(source, into: target, routines: routines, sessions: sessions, context: modelContext)
                mergeSource = nil
            }
        case is RepeaterExercise:
            LibraryPickerView<RepeaterExercise>(exclude: { $0.uuid == source.uuid }) { target in
                ExerciseLibrary.merge(source, into: target, routines: routines, sessions: sessions, context: modelContext)
                mergeSource = nil
            }
        case is MaxHangExercise:
            LibraryPickerView<MaxHangExercise>(exclude: { $0.uuid == source.uuid }) { target in
                ExerciseLibrary.merge(source, into: target, routines: routines, sessions: sessions, context: modelContext)
                mergeSource = nil
            }
        case is CampusLibraryExercise:
            LibraryPickerView<CampusLibraryExercise>(exclude: { $0.uuid == source.uuid }) { target in
                ExerciseLibrary.merge(source, into: target, routines: routines, sessions: sessions, context: modelContext)
                mergeSource = nil
            }
        default:
            EmptyView()
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        ExerciseLibraryView()
    }
}
