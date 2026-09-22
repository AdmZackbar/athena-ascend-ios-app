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
                let activeSessions = sessions.filter({ $0.endTime == nil }).sorted(by: { $0.startTime > $1.startTime })
                if !activeSessions.isEmpty {
                    Section("Active Sessions") {
                        sessionsView(sessions: activeSessions)
                    }
                }
                Section("Routines") {
                    routinesView()
                }
                let oldSessions = sessions.filter({ $0.endTime != nil }).sorted(by: { $0.startTime > $1.startTime })
                if !oldSessions.isEmpty {
                    Section("Previous Sessions") {
                        sessionsView(sessions: oldSessions)
                    }
                }
            }.navigationTitle("Zach Wassynger")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            navigationStore.push(ViewType.exerciseLibrary)
                        } label: {
                            Label("Exercise Library", systemImage: "list.bullet")
                        }
                        Button {
                            navigationStore.push(ViewType.repeaters)
                        } label: {
                            Label("View Repeaters", systemImage: "magnifyingglass")
                        }
                        Menu {
                            Button {
                                let session = Session()
                                modelContext.insert(session)
                                navigationStore.push(ViewType.session(session: session))
                            } label: {
                                Label("Start Fresh Session", systemImage: "clock")
                            }
                            Button {
                                navigationStore.push(ViewType.routineAdd)
                            } label: {
                                Label("Create New Routine", systemImage: "map")
                            }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }.navigationDestination(for: ViewType.self, destination: Self.handleView)
        }.environmentObject(navigationStore)
    }
    
    @ViewBuilder
    private func routinesView() -> some View {
        ForEach(routines.sorted(by: { lhs, rhs in
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
        })) { routine in
            Menu {
                Button {
                    let recentBodyWeight = sessions.sorted(by: { $0.startTime > $1.startTime }).first?.bodyWeight
                    let session = Session(sets: routine.sets.map(Session.ExerciseSet.init), bodyWeight: recentBodyWeight ?? 160, routineName: routine.name)
                    routine.sessions.append(session)
                    routine.lastUsedAt = .now
                    navigationStore.push(ViewType.session(session: session))
                } label: {
                    Label("Start Session", systemImage: "plus")
                }
                Button {
                    navigationStore.push(ViewType.routineView(routine: routine))
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
                        // Belt-and-suspenders: make sure every session's name snapshot is
                        // current before the `.nullify` delete rule severs `session.routine`.
                        for session in routine.sessions {
                            session.routineName = routine.name
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
    
    @ViewBuilder
    private func sessionsView(sessions: [Session]) -> some View {
        ForEach(sessions) { session in
            Button {
                navigationStore.push(ViewType.session(session: session))
            } label: {
                sessionView(session)
                    .contentShape(Rectangle())
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
    
    @ViewBuilder
    func sessionView(_ session: Session) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if let routine = session.routine {
                        Text(routine.name)
                            .italic()
                    } else if let routineName = session.routineName {
                        Text(routineName)
                            .italic()
                    }
                    Spacer()
                    if let endTime = session.endTime {
                        Text(Duration.seconds(endTime.timeIntervalSince(session.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }.font(.subheadline)
                HStack {
                    Text(session.startTime.formatted(date: .long, time: .omitted))
                    Spacer()
                    Text(session.startTime.formatted(date: .omitted, time: .shortened))
                }.fontWeight(.semibold)
                HStack {
                    Text(session.bodyWeight.lbsFormat)
                        .fontWeight(.light)
                    Spacer()
                }.font(.subheadline)
            }
            Spacer()
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
        case .routineView(let routine):
            RoutineView(routine: routine)
        case .session(let session):
            RoutineSessionView(session: session)
        case .repeaters:
            RepeaterOverview()
        case .exerciseLibrary:
            ExerciseLibraryView()
        }
    }
}

enum ViewType: Hashable {
    case routineAdd
    case routineEdit(routine: Routine)
    case routineView(routine: Routine)
    case session(session: Session)
    case repeaters
    case exerciseLibrary
}

#Preview(traits: .sampleData) {
    MainView()
}
