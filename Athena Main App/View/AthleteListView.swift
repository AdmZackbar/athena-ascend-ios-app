//
//  AthleteListView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/22/26.
//

import SwiftData
import SwiftUI

struct AthleteListView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Athlete.name) private var athletes: [Athlete]

    /// So the roster can mark which entry is currently selected on `MainView`
    let currentAthleteID: UUID

    @State private var deleteTarget: Athlete? = nil

    var body: some View {
        List {
            ForEach(athletes) { athlete in
                Button {
                    navigationStore.push(ViewType.athlete(athlete: athlete))
                } label: {
                    row(for: athlete)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteTarget = athlete
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }.disabled(athletes.count <= 1)
                    }
            }
        }.navigationTitle("Athletes")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Athlete?", isPresented: .init(get: {
                deleteTarget != nil
            }, set: { newValue in
                if !newValue {
                    deleteTarget = nil
                }
            })) {
                Button("Cancel", role: .cancel) {
                    deleteTarget = nil
                }
                Button("Delete", role: .destructive) {
                    if let deleteTarget {
                        modelContext.delete(deleteTarget)
                    }
                    deleteTarget = nil
                }
            } message: {
                if let deleteTarget {
                    let soloCount = deleteTarget.sessions.filter { !$0.isTeamEntry }.count
                    let teamCount = deleteTarget.sessions.filter(\.isTeamEntry).count
                    Text("Delete \(deleteTarget.name)? This also deletes their \(soloCount) session(s) and \(teamCount) team-session entry(ies). This can't be undone.")
                }
            }
    }

    @ViewBuilder
    private func row(for athlete: Athlete) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(athlete.name)
                    .fontWeight(.semibold)
                if athlete.uuid == currentAthleteID {
                    Text("Current")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tertiary, in: .capsule)
                }
                Spacer()
            }
            if let fullName = athlete.fullName {
                Text(fullName)
                    .font(.subheadline)
                    .italic()
            }
            if let lastUsedAt = athlete.lastUsedAt {
                Text("Last used \(lastUsedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
