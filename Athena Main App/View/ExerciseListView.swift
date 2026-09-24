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
    @Query private var routines: [Routine]
    @Query private var sessions: [Session]
    
    let athlete: Athlete
    
    var body: some View {
        let exerciseIds: Set<UUID> = Set(athlete.sessions
            .flatMap(\.sets)
            .flatMap(\.exercises)
            .compactMap(\.exerciseID))
        let athleteSessions = sessions.filter { $0.athlete?.uuid == athlete.uuid }
        List {
            ForEach(exercises.filter { exerciseIds.contains($0.uuid) }) { exercise in
                Button {
                    navigationStore.push(ViewType.exercise(exercise: exercise, athlete: athlete))
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                            .fontWeight(.semibold)
                        Text(subtitle(for: exercise))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        let usage = ExerciseLibrary.usageCount(of: exercise, routines: routines, sessions: athleteSessions)
                        Text("\(usage.sessions) session(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
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
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    NavigationStack {
        ExerciseListView(athlete: athletes.first!)
    }
}
