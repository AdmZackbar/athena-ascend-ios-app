//
//  RepWeightChart.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/26/26.
//

import Charts
import SwiftUI

extension [RepWeightChart.Data] {
    var minWeight: Double {
        return self.map({ $0.weight }).min() ?? 0
    }
    
    var maxWeight: Double {
        return self.map({ $0.weight }).max() ?? 0
    }
}

struct RepWeightChart: View {
    struct Key: Identifiable, Hashable, Equatable, Comparable {
        var id: Int {
            self.hashValue
        }
        
        let date: Date
        let reps: Int
        
        init(date: Date, reps: Int) {
            self.date = date
            self.reps = reps
        }
        
        static func < (lhs: RepWeightChart.Key, rhs: RepWeightChart.Key) -> Bool {
            if lhs.date == rhs.date {
                return lhs.reps < rhs.reps
            }
            return lhs.date < rhs.date
        }
    }
    
    let data: [Data]
    
    var body: some View {
        lineChartByReps()
            .frame(height: 170)
    }
    
    @ViewBuilder
    func lineChartByReps() -> some View {
//        let grouped = Dictionary(grouping: data, by: { Key(date: $0.date, reps: $0.reps) })
//        Chart(grouped.keys.sorted()) { d in
//            let min = grouped[d]!.minWeight
//            let max = grouped[d]!.maxWeight
//            if min == max {
//                PointMark(x: .value("Date", d.date), y: .value("Weight", min))
//                    .foregroundStyle(by: .value("Reps", "\(d.reps)"))
//            } else {
//                RuleMark(x: .value("Date", d.date), yStart: .value("Min Weight", min), yEnd: .value("Max Weight", max))
//                    .lineStyle(StrokeStyle(lineWidth: 6))
//                    .foregroundStyle(by: .value("Reps", "\(d.reps)"))
//            }
//        }
        Chart(data) { d in
            PointMark(x: .value("Date", d.date), y: .value("Weight", d.weight))
                .foregroundStyle(by: .value("Reps", "\(d.reps) reps"))
                .opacity(0.4)
        }
    }
    
    @ViewBuilder
    func scatterChart() -> some View {
        Chart(data) { d in
            PointMark(x: .value("Reps", d.reps), y: .value("Weight", d.weight))
                .foregroundStyle(by: .value("Date", d.date.formatted(date: .abbreviated, time: .omitted)))
                .opacity(0.4)
        }
    }
    
    struct Data: Identifiable, Hashable, Equatable {
        var id: UUID
        var date: Date
        var reps: Int
        var weight: Double
        
        init(date: Date, reps: Int, weight: Double) {
            self.id = .init()
            self.date = date
            self.reps = reps
            self.weight = weight
        }
    }
}

#Preview {
    let date = Date.now
    RepWeightChart(data: [.init(date: date, reps: 3, weight: 40), .init(date: date, reps: 2, weight: 50)])
}
