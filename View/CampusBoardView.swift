//
//  CampusBoardView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/24/26.
//

import SwiftUI

extension CampusMove {
    mutating func flip() {
        self.side = self.side.flipped
    }
}

extension CampusSet.Side {
    var color: some ShapeStyle {
        switch self {
        case .both: return .blue
        case .left: return .purple
        case .right: return .pink
        }
    }
}

extension CampusExercise {
    var text: String {
        switch self {
        case .basicLadder: return "Basic Ladder"
        case .maxLadder: return "Max Ladder"
        case .maxFirst: return "Max First"
        case .bumps: return "Bumps"
        case .touches: return "Touches"
        case .doubles: return "Doubles"
        case .downUps: return "Down-Ups"
        }
    }
    
    var start: CampusMove {
        switch self {
        case .doubles, .downUps:
            return .init(rung: .full(3), side: .both)
        default:
            return .init(rung: .full(1), side: .both)
        }
    }
}

struct CampusBoardView: View {
    typealias Side = CampusSet.Side
    
    let board: CampusBoard
    let exercise: CampusExercise
    @Binding var moves: [CampusMove]
    
    var body: some View {
        VStack {
            movesView()
            HStack {
                VStack {
                    ForEach(((board.startRung.num + (board.startRung.isHalf ? 1 : 0))...board.endRung.num).reversed().map({ CampusRung.full($0) }), id: \.text) { rung in
                        rungButton(rung)
                    }
                }
                if board.hasHalf {
                    VStack {
                        ForEach((board.startRung.num...(board.endRung.num - (board.endRung.isHalf ? 0 : 1))).reversed().map({ CampusRung.half($0) }), id: \.text) { rung in
                            rungButton(rung)
                        }
                    }
                }
            }
            Spacer()
        }.onAppear {
            if moves.isEmpty {
                moves = [exercise.start]
            }
        }
    }
    
    @ViewBuilder
    func movesView() -> some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(moves.enumerated(), id: \.offset) { offset, move in
                    Menu {
                        if move.side == .both {
                            Button {
                                moves[offset].side = .left
                            } label: {
                                Label("Left", systemImage: "hand.point.left")
                            }.tint(.primary)
                            Button {
                                moves[offset].side = .right
                            } label: {
                                Label("Right", systemImage: "hand.point.right")
                            }.tint(.primary)
                        } else {
                            Button {
                                moves[offset].side = .both
                            } label: {
                                Label("Both", systemImage: "hands.clap")
                            }.tint(.primary)
                            Button {
                                moves[offset].flip()
                            } label: {
                                Label("Flip", systemImage: "arrow.trianglehead.left.and.right.righttriangle.left.righttriangle.right")
                            }.tint(.primary)
                        }
                        Divider()
                        Button(role: .destructive) {
                            moves.remove(at: offset)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }.tint(.red)
                    } label: {
                        Text(move.text)
                            .font(.title2)
                            .bold()
                    }.buttonStyle(.bordered)
                        .tint(move.side.color)
                }
            }
        }.scrollTargetBehavior(.viewAligned)
    }
    
    @ViewBuilder
    func rungButton(_ rung: CampusRung) -> some View {
        Button {
            moves.append(.init(rung: rung, side: computeInitialGrip(rung)))
        } label: {
            rungView(rung)
        }.buttonStyle(.borderedProminent)
            .tint(.primary)
            .contextMenu {
                rungActions(rung)
            }
    }
    
    private func computeInitialGrip(_ rung: CampusRung) -> Side {
        guard let last = moves.last else { return .both }
        switch exercise {
        case .doubles, .downUps:
            return .both
        case .bumps:
            switch last.side {
            case .both, .right:
                return .right
            case .left:
                return .left
            }
        default:
            if last.rung == rung {
                return .both
            }
            switch last.side {
            case .both, .left:
                return .right
            case .right:
                return .left
            }
        }
    }
    
    @ViewBuilder
    func rungActions(_ rung: CampusRung) -> some View {
        Button {
            moves.append(.init(rung: rung, side: .both))
        } label: {
            Label("Both", systemImage: "hands.clap")
        }.tint(.primary)
        Button {
            moves.append(.init(rung: rung, side: .left))
        } label: {
            Label("Left", systemImage: "hand.point.left")
        }.tint(.primary)
        Button {
            moves.append(.init(rung: rung, side: .right))
        } label: {
            Label("Right", systemImage: "hand.point.right")
        }.tint(.primary)
    }
    
    @ViewBuilder
    func rungView(_ rung: CampusRung) -> some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(moves.filter({ $0.rung == rung }).enumerated(), id: \.offset) { offset, move in
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(move.side.color)
                }
                Spacer()
            }
            HStack {
                Spacer()
                Text(rung.text)
                Spacer()
            }.font(.title3)
                .fontWeight(.heavy)
        }
    }
}

#Preview {
    @Previewable @State var exercise: Routine.CampusSets.Exercise = .maxLadder
    @Previewable @State var moves: [CampusMove] = []
    Form {
        Picker("Campus Type", selection: $exercise) {
            ForEach(Routine.CampusSets.Exercise.allCases, id: \.text) { exercise in
                Text(exercise.text).tag(exercise)
            }
        }.pickerStyle(.menu)
        CampusBoardView(board: .largeEdges, exercise: exercise, moves: $moves)
    }
}
