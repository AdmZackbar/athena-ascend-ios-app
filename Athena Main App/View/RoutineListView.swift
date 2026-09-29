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
    
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    
    let athlete: Athlete
    
    var body: some View {
        List {
            ForEach(routines) { routine in
                routineEntryView(routine)
            }
        }
    }
    
    @ViewBuilder
    func routineEntryView(_ routine: Routine) -> some View {
        Menu {
            Button {
                let session: Session = .init(routine: routine, superSets: routine.superSets)
                modelContext.insert(session)
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
            HStack {
                Text(routine.name)
                    .fontWeight(.semibold)
                Spacer()
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    RoutineListView(athlete: athletes.first!)
}
