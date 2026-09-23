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
    
    /// A row in the session list is either a solo `Session` or a `TeamSession` — the
    /// latter's per-athlete `Session` entries are never shown as standalone rows here.
    private enum SessionRow: Hashable {
        case solo(_ session: Session)
        case team(_ teamSession: TeamSession)

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

    /// This athlete's own sessions plus every team session that includes them
    private func rows(currentAthlete: Athlete) -> [SessionRow] {
        let solo = sessions
            .filter { !$0.isTeamEntry && $0.athlete?.uuid == currentAthlete.uuid }
            .map(SessionRow.solo)
        let team = teamSessions
            .filter { $0.entries.contains(where: { $0.athlete?.uuid == currentAthlete.uuid }) }
            .map(SessionRow.team)
        return solo + team
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    NavigationStack {
        SessionListView(athlete: athletes.first!)
    }
}
