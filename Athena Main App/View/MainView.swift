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
    
    @Query(sort: [
        SortDescriptor(\Athlete.lastUsedAt, order: .reverse),
        SortDescriptor(\Athlete.name)
    ]) private var athletes: [Athlete]
    @AppStorage(CurrentAthlete.storageKey) private var currentAthleteID: String = ""
    /// Derived fresh from `athletes` on every access rather than cached in `@State` —
    /// caching a SwiftData model reference risks it outliving the query/graph that
    /// produced it (e.g. across a container swap), which can trip an AttributeGraph
    /// "different namespace" crash. `.task`/`.onChange` below only handle the seeding
    /// side effect (inserting a default athlete when the roster is empty).
    private var currentAthlete: Athlete? {
        athletes.first(where: { $0.uuid.uuidString == currentAthleteID })
    }
    
    @State private var viewType: MainViewType = .session

    var body: some View {
        NavigationStack(path: $navigationStore.path) {
            TabView(selection: $viewType) {
                ForEach(MainViewType.allCases, id: \.name) { type in
                    getView(type)
                        .tag(type)
                        .tabItem {
                            Label(type.name, systemImage: type.icon)
                        }
                }
            }.navigationTitle(currentAthlete?.fullName ?? currentAthlete?.name ?? "Select Athlete")
                .navigationBarTitleDisplayMode(.inline)
                .handleDestinations(navigationStore)
                .toolbar {
                    ToolbarTitleMenu {
                        ForEach(athletes) { athlete in
                            Button {
                                currentAthleteID = athlete.uuid.uuidString
                            } label: {
                                if athlete.uuid == currentAthlete?.uuid {
                                    Label(athlete.name, systemImage: "checkmark")
                                } else {
                                    Text(athlete.name)
                                }
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Menu {
                            Button {
                                navigationStore.push(ViewType.exerciseLibrary)
                            } label: {
                                Label("View Exercises", systemImage: "tablecells")
                            }
                            Button {
                                navigationStore.push(ViewType.athleteList(athlete: currentAthlete!))
                            } label: {
                                Label("Manage Athletes", systemImage: "person.2")
                            }.disabled(currentAthlete == nil)
                        } label: {
                            Label("Options", systemImage: "ellipsis")
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                let session = Session(athlete: currentAthlete!)
                                modelContext.insert(session)
                                navigationStore.push(ViewType.session(session: session))
                            } label: {
                                Label("Start Fresh Session", systemImage: "clock")
                            }.disabled(currentAthlete == nil)
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
                }
                .task {
                    resolveCurrentAthlete()
                }
                .onChange(of: athletes) { _, _ in
                    resolveCurrentAthlete()
                }
        }.environmentObject(navigationStore)
    }
    
    private func resolveCurrentAthlete() {
        guard currentAthlete == nil else { return }
        let resolved = CurrentAthlete.resolve(storedID: currentAthleteID, athletes: athletes, context: modelContext)
        currentAthleteID = resolved.uuid.uuidString
    }
    
    @ViewBuilder
    private func getView(_ type: MainViewType) -> some View {
        if let currentAthlete {
            switch type {
            case .exercise:
                ExerciseListView(athlete: currentAthlete)
            case .routine:
                RoutineListView(athlete: currentAthlete)
            case .session:
                SessionListView(athlete: currentAthlete)
            }
        } else {
            ProgressView()
        }
    }
    
    private enum MainViewType: CaseIterable, Hashable {
        case session, routine, exercise
        
        var name: String {
            switch self {
            case .exercise:
                return "Exercises"
            case .routine:
                return "Routines"
            case .session:
                return "Sessions"
            }
        }
        
        var icon: String {
            switch self {
            case .exercise:
                return "tablecells"
            case .routine:
                return "book"
            case .session:
                return "calendar"
            }
        }
    }
}

#Preview(traits: .sampleData) {
    MainView()
}
