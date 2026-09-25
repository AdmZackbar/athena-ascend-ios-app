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
    
    let athlete: Athlete
    
    var body: some View {
        List {
            let activeRows = sessions.filter({ $0.endTime == nil }).sorted(by: { $0.startTime > $1.startTime })
            if !activeRows.isEmpty {
                Section("Active Sessions") {
                    sessionsView(activeRows)
                }
            }
            let oldRows = sessions.filter({ $0.endTime != nil }).sorted(by: { $0.startTime > $1.startTime })
            if !oldRows.isEmpty {
                Section("Previous Sessions") {
                    sessionsView(oldRows)
                }
            }
        }
    }
    
    @ViewBuilder
    private func sessionsView(_ sessions: [Session]) -> some View {
        ForEach(sessions, id: \.self) { session in
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
                Group {
                    if let routine = session.routine {
                        Text(routine.name)
                    }
                }.font(.subheadline)
                    .italic()
                HStack {
                    Text(session.startTime.formatted(date: .long, time: .omitted))
                    Spacer()
                    Text(session.startTime.formatted(date: .omitted, time: .shortened))
                }.fontWeight(.semibold)
                HStack {
                    Spacer()
                    if let endTime = session.endTime {
                        Text(Duration.seconds(endTime.timeIntervalSince(session.startTime)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }.font(.subheadline)
            }
            Spacer()
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    NavigationStack {
        SessionListView(athlete: athletes.first!)
    }
}
