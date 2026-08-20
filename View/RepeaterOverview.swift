//
//  RepeaterOverview.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/20/26.
//

import SwiftData
import SwiftUI

struct RepeaterOverview: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    
    var body: some View {
        let repeaters: [(Session, Session.RepeaterData)] = {
            sessions.flatMap({ session in
                let repeaters = session.sets
                    .flatMap({ $0.exercises })
                    .map({ exercise in
                        switch exercise {
                        case .repeater(let d):
                            return d as Session.RepeaterData?
                        default:
                            return nil
                        }
                    })
                    .filter({ $0 != nil })
                    .map({ $0! })
                return repeaters.map({ (session, $0) })
            })
        }()
        let map = Dictionary(grouping: repeaters, by: { $0.1.expected.tag })
        Form {
            ForEach(map.sorted(by: { $0.key < $1.key }), id: \.key) { tag, pairs in
                Section(tag) {
                    ForEach(pairs.enumerated(), id: \.offset) { offset, pair in
                        VStack(alignment: .leading) {
                            let session = pair.0
                            let data = pair.1
                            Text(session.startTime.formatted(date: .numeric, time: .shortened))
                                .bold()
                            VStack(alignment: .leading) {
                                ForEach(data.actual.enumerated(), id: \.offset) { offset, set in
                                    Text(set.text)
                                }
                            }.font(.subheadline)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
        }.navigationTitle("All Repeaters")
    }
}

#Preview(traits: .modifier(TestDataModifier())) {
    NavigationStack {
        RepeaterOverview()
    }
}
