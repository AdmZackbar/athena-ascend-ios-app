//
//  MainView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @StateObject private var navigationStore = NavigationStore()
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]
    @Query private var sessions: [Session]

    var body: some View {
        NavigationStack(path: $navigationStore.path) {
            List {
                Section("Routines") {
                    routinesView()
                }
                let activeSessions = sessions.filter({ $0.endTime == nil })
                if !activeSessions.isEmpty {
                    Section("Active Sessions") {
                        sessionsView(sessions: activeSessions)
                    }
                }
                let oldSessions = sessions.filter({ $0.endTime != nil })
                if !oldSessions.isEmpty {
                    Section("Previous Sessions") {
                        sessionsView(sessions: oldSessions)
                    }
                }
            }.navigationTitle("Zach Wassynger")
                .toolbar {
                    ToolbarItem {
                        Button {
                            navigationStore.push(ViewType.routineAdd)
                        } label: {
                            Label("Add Routine", systemImage: "plus")
                        }
                    }
                }.navigationDestination(for: ViewType.self, destination: Self.handleView)
        }.environmentObject(navigationStore)
    }
    
    @ViewBuilder
    private func routinesView() -> some View {
        ForEach(routines) { routine in
            Menu {
                Button {
                    let session = Session(sets: routine.sets.map(Session.ExerciseSet.init))
                    routine.sessions.append(session)
                    navigationStore.push(ViewType.session(session: session))
                } label: {
                    Label("Start Session", systemImage: "plus")
                }
                Button {
                    navigationStore.push(ViewType.routineEdit(routine: routine))
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
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
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func sessionsView(sessions: [Session]) -> some View {
        ForEach(sessions) { session in
            Button {
                navigationStore.push(ViewType.session(session: session))
            } label: {
                HStack {
                    Text(session.routine?.name ?? "Session \(session.startTime.formatted(date: .abbreviated, time: .omitted))")
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    @MainActor
    @ViewBuilder
    static func handleView(_ view: ViewType) -> some View {
        switch view {
        case .routineAdd:
            RoutineEditView()
        case .routineEdit(let routine):
            RoutineEditView(routine: routine)
        case .session(let session):
            RoutineSessionView(session: session)
        }
    }
}

enum ViewType: Hashable {
    case routineAdd
    case routineEdit(routine: Routine)
    case session(session: Session)
}

#Preview(traits: .modifier(TestDataModifier())) {
    MainView()
}
