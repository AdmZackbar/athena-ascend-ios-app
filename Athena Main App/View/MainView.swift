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
    @Query(sort: [
        SortDescriptor(\Athlete.lastUsedAt, order: .reverse),
        SortDescriptor(\Athlete.name)
    ]) private var athletes: [Athlete]
    @Query private var teamSessions: [TeamSession]

    @AppStorage(CurrentAthlete.storageKey) private var currentAthleteID: String = ""
    /// Derived fresh from `athletes` on every access rather than cached in `@State` —
    /// caching a SwiftData model reference risks it outliving the query/graph that
    /// produced it (e.g. across a container swap), which can trip an AttributeGraph
    /// "different namespace" crash. `.task`/`.onChange` below only handle the seeding
    /// side effect (inserting a default athlete when the roster is empty).
    private var currentAthlete: Athlete? {
        athletes.first(where: { $0.uuid.uuidString == currentAthleteID })
    }

    /// A row in the session list is either a solo `Session` or a `TeamSession` — the
    /// latter's per-athlete `Session` entries are never shown as standalone rows here.
    private enum SessionRow: Hashable {
        case solo(Session)
        case team(TeamSession)

        var startTime: Date {
            switch self {
            case .solo(let session): return session.startTime
            case .team(let teamSession): return teamSession.startTime
            }
        }

        var endTime: Date? {
            switch self {
            case .solo(let session): return session.endTime
            case .team(let teamSession): return teamSession.endTime
            }
        }
    }

    /// This athlete's own sessions plus every team session, regardless of who's in
    /// it — team sessions span the whole roster, so they stay visible no matter which
    /// athlete is currently selected.
    private func rows(currentAthlete: Athlete) -> [SessionRow] {
        let solo = sessions
            .filter { !$0.isTeamEntry && $0.athlete?.uuid == currentAthlete.uuid }
            .map(SessionRow.solo)
        return solo + teamSessions.map(SessionRow.team)
    }

    var body: some View {
        NavigationStack(path: $navigationStore.path) {
            Group {
                if let currentAthlete {
                    listContent(currentAthlete: currentAthlete)
                } else {
                    ProgressView()
                }
            }
        }.environmentObject(navigationStore)
            .task {
                resolveCurrentAthlete()
            }
            .onChange(of: athletes) { _, _ in
                resolveCurrentAthlete()
            }
    }

    private func resolveCurrentAthlete() {
        guard currentAthlete == nil else { return }
        let resolved = CurrentAthlete.resolve(storedID: currentAthleteID, athletes: athletes, context: modelContext)
        currentAthleteID = resolved.uuid.uuidString
    }

    @ViewBuilder
    private func listContent(currentAthlete: Athlete) -> some View {
        let sessionRows = rows(currentAthlete: currentAthlete)
        List {
            let activeRows = sessionRows.filter({ $0.endTime == nil }).sorted(by: { $0.startTime > $1.startTime })
            if !activeRows.isEmpty {
                Section("Active Sessions") {
                    rowsView(activeRows)
                }
            }
            Section("Routines") {
                routinesView(currentAthlete: currentAthlete)
            }
            let oldRows = sessionRows.filter({ $0.endTime != nil }).sorted(by: { $0.startTime > $1.startTime })
            if !oldRows.isEmpty {
                Section("Previous Sessions") {
                    rowsView(oldRows)
                }
            }
        }.navigationTitle(currentAthlete.name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarTitleMenu {
                    ForEach(athletes) { athlete in
                        Button {
                            currentAthleteID = athlete.uuid.uuidString
                        } label: {
                            if athlete.uuid == currentAthlete.uuid {
                                Label(athlete.name, systemImage: "checkmark")
                            } else {
                                Text(athlete.name)
                            }
                        }
                    }
                    Divider()
                    Button {
                        navigationStore.push(ViewType.athleteLibrary)
                    } label: {
                        Label("Manage Athletes…", systemImage: "person.2")
                    }
                }
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
                            let session = Session(athlete: currentAthlete)
                            modelContext.insert(session)
                            navigationStore.push(ViewType.session(session: session))
                        } label: {
                            Label("Start Fresh Session", systemImage: "clock")
                        }
                        Button {
                            let teamSession = TeamSession()
                            modelContext.insert(teamSession)
                            navigationStore.push(ViewType.teamSession(session: teamSession))
                        } label: {
                            Label("Start Team Session", systemImage: "person.3")
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
            }.navigationDestination(for: ViewType.self) { view in
                handleView(view, currentAthlete: currentAthlete)
            }
    }

    @ViewBuilder
    private func routinesView(currentAthlete: Athlete) -> some View {
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
                    let recentBodyWeight = currentAthlete.sessions
                        .sorted(by: { $0.startTime > $1.startTime })
                        .first?.bodyWeight
                    let session = Session(sets: routine.sets.map(Session.ExerciseSet.init), bodyWeight: recentBodyWeight ?? 160, routineName: routine.name, athlete: currentAthlete)
                    routine.sessions.append(session)
                    routine.lastUsedAt = .now
                    currentAthlete.lastUsedAt = .now
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

    @ViewBuilder
    private func rowsView(_ rows: [SessionRow]) -> some View {
        ForEach(rows, id: \.self) { row in
            switch row {
            case .solo(let session):
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
            case .team(let teamSession):
                Button {
                    navigationStore.push(ViewType.teamSession(session: teamSession))
                } label: {
                    teamSessionView(teamSession)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(teamSession)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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

    @ViewBuilder
    func teamSessionView(_ teamSession: TeamSession) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if let routine = teamSession.routine {
                        Text(routine.name)
                            .italic()
                    } else if let routineName = teamSession.routineName {
                        Text(routineName)
                            .italic()
                    }
                    Spacer()
                    if let endTime = teamSession.endTime {
                        Text(Duration.seconds(endTime.timeIntervalSince(teamSession.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }.font(.subheadline)
                HStack {
                    Text(teamSession.startTime.formatted(date: .long, time: .omitted))
                    Spacer()
                    Text(teamSession.startTime.formatted(date: .omitted, time: .shortened))
                }.fontWeight(.semibold)
                HStack {
                    Text("\(teamSession.entries.count) athlete(s)")
                        .fontWeight(.light)
                    Spacer()
                }.font(.subheadline)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func handleView(_ view: ViewType, currentAthlete: Athlete) -> some View {
        switch view {
        case .routineAdd:
            RoutineEditView()
        case .routineEdit(let routine):
            RoutineEditView(routine: routine)
        case .routineView(let routine):
            RoutineView(routine: routine, athlete: currentAthlete)
        case .session(let session):
            RoutineSessionView(session: session)
        case .teamSession(let teamSession):
            TeamSessionView(teamSession: teamSession)
        case .repeaters:
            RepeaterOverview(athlete: currentAthlete)
        case .exerciseLibrary:
            ExerciseLibraryView()
        case .athleteLibrary:
            AthleteLibraryView(currentAthleteID: currentAthlete.uuid)
        }
    }
}

enum ViewType: Hashable {
    case routineAdd
    case routineEdit(routine: Routine)
    case routineView(routine: Routine)
    case session(session: Session)
    case teamSession(session: TeamSession)
    case repeaters
    case exerciseLibrary
    case athleteLibrary
}

#Preview(traits: .sampleData) {
    MainView()
}
