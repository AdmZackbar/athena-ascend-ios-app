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

    /// So the roster can mark which entry is currently selected on `MainView`.
    /// Switching athletes happens from `MainView`'s title menu, not here.
    let currentAthleteID: UUID

    @State private var renamingAthlete: Athlete? = nil
    @State private var renameText: String = ""
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
                        Button {
                            renameText = athlete.name
                            renamingAthlete = athlete
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteTarget = athlete
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }.disabled(athletes.count <= 1)
                    }
            }
        }.navigationTitle("Athletes")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Rename Athlete", isPresented: .init(get: {
                renamingAthlete != nil
            }, set: { newValue in
                if !newValue {
                    renamingAthlete = nil
                }
            })) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renamingAthlete = nil
                }
                Button("Save") {
                    if let renamingAthlete, !renameText.isEmpty {
                        renamingAthlete.name = renameText
                    }
                    renamingAthlete = nil
                }
            }
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
