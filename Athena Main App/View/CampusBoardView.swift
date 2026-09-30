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

struct CampusBoardView: View {
    @Environment(\.dismiss) var dismiss
    
    typealias Side = CampusSet.Side
    
    let onComplete: (CampusSet) -> Void
    @State var board: CampusBoard
    @State var moves: [CampusMove]
    @State private var behavior: SelectBehavior = .regular
    
    init(set: CampusSet, onComplete: @escaping (CampusSet) -> Void) {
        self.onComplete = onComplete
        self.board = set.board
        self.moves = set.moves
    }
    
    var body: some View {
        Form {
            Section {
                VStack {
                    if !moves.isEmpty {
                        movesView()
                    } else {
                        Button {
                            // Do nothing
                        } label: {
                            Text("No Moves Set")
                                .bold()
                                .italic()
                        }.buttonStyle(.glass)
                            .tint(.primary)
                    }
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
                }
            } header: {
                Picker("Campus Board", selection: $board) {
                    ForEach(CampusBoard.allCases, id: \.name) { b in
                        Text(b.abbreviation).tag(b)
                    }
                }.pickerStyle(.segmented)
            } footer: {
                VStack(alignment: .leading) {
                    Text(board.name)
                    Text(moves.text)
                }.font(.subheadline)
                    .fontWeight(.heavy)
            }
        }.navigationTitle("Edit Moves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        ForEach(SelectBehavior.allCases, id: \.name) { b in
                            Button {
                                behavior = b
                            } label: {
                                Label(b.name, systemImage: b.icon)
                            }.disabled(behavior == b)
                        }
                    } label: {
                        Label("Behavior", systemImage: "ellipsis")
                    }
                    Button {
                        moves.removeAll()
                    } label: {
                        Label("Clear", systemImage: "clear")
                    }
                    Button {
                        onComplete(.init(board: board, moves: moves))
                        dismiss()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
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
                            .bold()
                    }.buttonStyle(.glass)
                        .tint(move.side.color)
                }
            }
        }
    }
    
    @ViewBuilder
    func rungButton(_ rung: CampusRung) -> some View {
        Button {
            moves.append(.init(rung: rung, side: computeInitialGrip(rung)))
        } label: {
            rungView(rung)
        }.buttonStyle(.glass)
            .foregroundStyle(.primary)
    }
    
    private func computeInitialGrip(_ rung: CampusRung) -> Side {
        switch behavior {
        case .regular:
            guard let last = moves.last else { return .both }
            if last.rung == rung {
                return .both
            }
            switch last.side {
            case .both, .right:
                return .left
            case .left:
                return .right
            }
        case .doubles:
            return .both
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
    
    enum SelectBehavior: CaseIterable {
        case regular
        case doubles
        
        var name: String {
            switch self {
            case .regular:
                "Regular"
            case .doubles:
                "Doubles"
            }
        }
        
        var icon: String {
            switch self {
            case .regular:
                "hand.raised"
            case .doubles:
                "hands.clap"
            }
        }
    }
}

#Preview {
    NavigationStack {
        CampusBoardView(set: .init(board: .largeEdges, moves: [.init(rung: .full(1), side: .both)])) { moves in
            // TODO
        }
    }
}
