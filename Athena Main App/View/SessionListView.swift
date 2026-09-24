//
//  SessionListView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

struct SessionListView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    @Environment(\.modelContext) private var modelContext
    
    @Query private var sessions: [Session]
    @Query private var teamSessions: [TeamSession]
    
    let athlete: Athlete
    
    var body: some View {
        let sessionRows = rows(currentAthlete: athlete)
        List {
            let activeRows = sessionRows.filter({ $0.endTime == nil }).sorted(by: { $0.startTime > $1.startTime })
            if !activeRows.isEmpty {
                Section("Active Sessions") {
                    rowsView(activeRows)
                }
            }
            let oldRows = sessionRows.filter({ $0.endTime != nil }).sorted(by: { $0.startTime > $1.startTime })
            if !oldRows.isEmpty {
                Section("Previous Sessions") {
                    rowsView(oldRows)
                }
            }
        }
    }
    
    @ViewBuilder
    private func rowsView(_ rows: [SessionRow]) -> some View {
        ForEach(rows, id: \.self) { row in
            switch row {
            case .solo(_, let session):
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
            case .team(_, let teamSession):
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
                Group {
                    if let routine = session.routine {
                        Text(routine.name)
                    } else if let routineName = session.routineName {
                        Text(routineName)
                    }
                }.font(.subheadline)
                    .italic()
                HStack {
                    Text(session.startTime.formatted(date: .long, time: .omitted))
                    Spacer()
                    Text(session.startTime.formatted(date: .omitted, time: .shortened))
                }.fontWeight(.semibold)
                HStack {
                    Text(session.bodyWeight.lbsFormat)
                        .fontWeight(.light)
                    Spacer()
                    if let endTime = session.endTime {
                        Text(Duration.seconds(endTime.timeIntervalSince(session.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }.font(.subheadline)
            }
            Spacer()
        }
    }

    @ViewBuilder
    func teamSessionView(_ teamSession: TeamSession) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Group {
                    if let routine = teamSession.routine {
                        Text(routine.name)
                    } else if let routineName = teamSession.routineName {
                        Text(routineName)
                    }
                }.font(.subheadline)
                    .italic()
                HStack {
                    Text(teamSession.startTime.formatted(date: .long, time: .omitted))
                    Spacer()
                    Text(teamSession.startTime.formatted(date: .omitted, time: .shortened))
                }.fontWeight(.semibold)
                HStack {
                    Text("\(teamSession.entries.count) athlete(s)")
                        .fontWeight(.light)
                    Spacer()
                    if let endTime = teamSession.endTime {
                        Text(Duration.seconds(endTime.timeIntervalSince(teamSession.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }.font(.subheadline)
            }
            Spacer()
        }
    }
    
    /// A row in the session list is either a solo `Session` or a `TeamSession` — the
    /// latter's per-athlete `Session` entries are never shown as standalone rows here.
    private enum SessionRow: Hashable {
        case solo(index: Int, session: Session)
        case team(index: Int, teamSession: TeamSession)

        var startTime: Date {
            switch self {
            case .solo(_, let session): return session.startTime
            case .team(_, let teamSession): return teamSession.startTime
            }
        }

        var endTime: Date? {
            switch self {
            case .solo(_, let session): return session.endTime
            case .team(_, let teamSession): return teamSession.endTime
            }
        }
        
        static func == (lhs: SessionRow, rhs: SessionRow) -> Bool {
            switch lhs {
            case .solo(let a, _):
                switch rhs {
                case .solo(let b, _):
                    return a == b
                case .team(_, _):
                    return false
                }
            case .team(let a, _):
                switch rhs {
                case .solo(_, _):
                    return false
                case .team(let b, _):
                    return a == b
                }
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .solo(let i, _):
                hasher.combine(i)
            case .team(let i, _):
                hasher.combine(i)
            }
        }
    }

    /// This athlete's own sessions plus every team session that includes them
    private func rows(currentAthlete: Athlete) -> [SessionRow] {
        let solo = sessions
            .filter { !$0.isTeamEntry && $0.athlete?.uuid == currentAthlete.uuid }
            .enumerated()
            .map { SessionRow.solo(index: $0, session: $1) }
        let team = teamSessions
            .filter { $0.entries.contains(where: { $0.athlete?.uuid == currentAthlete.uuid }) }
            .enumerated()
            .map { SessionRow.team(index: $0 + solo.count, teamSession: $1) }
        return solo + team
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    NavigationStack {
        SessionListView(athlete: athletes.first!)
    }
}
