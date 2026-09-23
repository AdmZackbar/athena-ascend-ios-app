//
//  AthleteView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

/// One athlete's history: every solo session plus every team-session entry they
/// took part in, newest first.
struct AthleteView: View {
    @State var athlete: Athlete

    private var soloSessions: [Session] {
        athlete.sessions.filter { !$0.isTeamEntry }.sorted(by: { $0.startTime > $1.startTime })
    }

    private var teamEntries: [Session] {
        athlete.sessions.filter(\.isTeamEntry).sorted(by: { $0.startTime > $1.startTime })
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Nickname", text: $athlete.name)
                TextField("First Name", text: .init(get: {
                    athlete.firstName ?? ""
                }, set: { newValue in
                    athlete.firstName = newValue.isEmpty ? nil : newValue
                }))
                TextField("Last Name", text: .init(get: {
                    athlete.lastName ?? ""
                }, set: { newValue in
                    athlete.lastName = newValue.isEmpty ? nil : newValue
                }))
            }
            if soloSessions.isEmpty && teamEntries.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(.secondary)
            }
            if !soloSessions.isEmpty {
                Section("Sessions") {
                    ForEach(soloSessions) { session in
                        NavigationLink {
                            SessionView(session: session)
                        } label: {
                            historyRow(date: session.startTime, label: session.routine?.name ?? session.routineName)
                        }
                    }
                }
            }
            if !teamEntries.isEmpty {
                Section("Team Sessions") {
                    ForEach(teamEntries) { entry in
                        if let teamSession = entry.teamSession {
                            NavigationLink {
                                TeamAthleteDetailView(entry: entry)
                            } label: {
                                historyRow(date: teamSession.startTime, label: teamSession.routine?.name ?? teamSession.routineName)
                            }
                        }
                    }
                }
            }
        }.navigationTitle(athlete.name)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func historyRow(date: Date, label: String?) -> some View {
        VStack(alignment: .leading) {
            if let label {
                Text(label)
                    .italic()
                    .font(.subheadline)
            }
            Text(date.formatted(date: .abbreviated, time: .shortened))
                .fontWeight(.semibold)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    AthleteView(athlete: athletes.first!)
}
