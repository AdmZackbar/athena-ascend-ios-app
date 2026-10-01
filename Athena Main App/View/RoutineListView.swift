//
//  RoutineListView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

struct RoutineListView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    
    let athlete: Athlete
    
    var body: some View {
        List {
            Section("All Routines") {
                ForEach(routines) { routine in
                    routineEntryView(routine)
                }
            }
        }
    }
    
    @ViewBuilder
    func routineEntryView(_ routine: Routine) -> some View {
        Menu {
            Button {
                let session: Session = .init(routine: routine, superSets: routine.superSets)
                modelContext.insert(session)
                session.addAthletes([athlete])
                navigationStore.push(ViewType.session(session: session))
            } label: {
                Label("Start Session", systemImage: "plus")
            }
            Button {
                navigationStore.push(ViewType.routineEdit(routine: routine))
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                withAnimation {
                    modelContext.delete(routine)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            routineView(routine)
        }.buttonStyle(.plain)
    }
    
    @ViewBuilder
    func routineView(_ routine: Routine) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("\(routine.sessions.count) sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(routine.name)
                    .fontWeight(.semibold)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Created At")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(routine.createdAt.formatted(date: .numeric, time: .omitted))
                    .fontWeight(.semibold)
            }
        }.contentShape(Rectangle())
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    RoutineListView(athlete: athletes.first!)
}
