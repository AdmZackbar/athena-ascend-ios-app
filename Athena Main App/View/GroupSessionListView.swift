//
//  GroupSessionListView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/28/26.
//

import SwiftData
import SwiftUI

struct GroupSessionListView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    
    var body: some View {
        List {
            Section("Group Sessions") {
                ForEach(sessions.filter({ $0.athletes.count > 1 }), id: \.self) { session in
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
    GroupSessionListView()
}
