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
    
    @Query private var routines: [Routine]
    @Query(sort: [
        SortDescriptor(\Athlete.lastUsedAt, order: .reverse),
        SortDescriptor(\Athlete.name)
    ]) private var athletes: [Athlete]
    
    let athlete: Athlete
    
    var body: some View {
        let sortedRoutines = routines.sorted(by: { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case (let l?, let r?):
                return l > r
            case (nil, nil):
                return lhs.name < rhs.name
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            }
        })
        List {
            ForEach(sortedRoutines) { routine in
                routineEntryView(routine)
            }
        }
    }
    
    @ViewBuilder
    func routineEntryView(_ routine: Routine) -> some View {
        Menu {
            Button {
                let recentBodyWeight = athlete.sessions
                    .sorted(by: { $0.startTime > $1.startTime })
                    .first?.bodyWeight
                let session = Session(sets: routine.sets.map(Session.ExerciseSet.init), bodyWeight: recentBodyWeight ?? 160, routineName: routine.name, athlete: athlete)
                routine.sessions.append(session)
                routine.lastUsedAt = .now
                athlete.lastUsedAt = .now
                navigationStore.push(ViewType.session(session: session))
            } label: {
                Label("Start Session", systemImage: "plus")
            }
            Button {
                let teamSession = TeamSession(routineName: routine.name, sets: routine.sets.map(Session.ExerciseSet.init))
                routine.teamSessions.append(teamSession)
                routine.lastUsedAt = .now
                navigationStore.push(ViewType.teamSession(session: teamSession))
            } label: {
                Label("Start Team Session", systemImage: "person.3")
            }
            Button {
                navigationStore.push(ViewType.routineView(routine: routine, athlete: athlete))
            } label: {
                Label("View Data", systemImage: "magnifyingglass")
            }
            Button {
                navigationStore.push(ViewType.routineEdit(routine: routine))
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                withAnimation {
                    // Belt-and-suspenders: make sure every session/team-session's
                    // name snapshot is current before the `.nullify` delete rule
                    // severs the routine link.
                    for session in routine.sessions {
                        session.routineName = routine.name
                    }
                    for teamSession in routine.teamSessions {
                        teamSession.routineName = routine.name
                    }
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
