//
//  NavigationStore.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
internal import Combine

@MainActor
final class NavigationStore: ObservableObject {
    @Published var path = NavigationPath()
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    func encoded() -> Data? {
        try? path.codable.map(encoder.encode)
    }
    
    func restore(from data: Data) {
        do {
            let codable = try decoder.decode(
                NavigationPath.CodableRepresentation.self, from: data
            )
            path = NavigationPath(codable)
        } catch {
            path = NavigationPath()
        }
    }
    
    func push(_ value: any Hashable) {
        path.append(value)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func replace(_ value: any Hashable) {
        pop()
        push(value)
    }
    
    @ViewBuilder
    func handleView(_ view: ViewType) -> some View {
        switch view {
        case .routineAdd:
            RoutineEditView()
        case .routineEdit(let routine):
            RoutineEditView(routine: routine)
        case .routineView(let routine, let athlete):
            RoutineView(routine: routine, athlete: athlete)
        case .session(let session):
            SessionView(session: session)
        case .teamSession(let teamSession):
            TeamSessionView(teamSession: teamSession)
        case .repeaters(let athlete):
            RepeaterOverview(athlete: athlete)
        case .exerciseLibrary:
            ExerciseLibraryView()
        case .athleteLibrary(let athlete):
            AthleteLibraryView(currentAthleteID: athlete.uuid)
        }
    }
}

enum ViewType: Hashable {
    case routineAdd
    case routineEdit(routine: Routine)
    case routineView(routine: Routine, athlete: Athlete? = nil)
    case session(session: Session)
    case teamSession(session: TeamSession)
    case repeaters(athlete: Athlete)
    case exerciseLibrary
    case athleteLibrary(athlete: Athlete)
}

extension View {
    func handleDestinations(_ navigationStore: NavigationStore) -> some View {
        self.navigationDestination(for: ViewType.self, destination: navigationStore.handleView)
    }
}
