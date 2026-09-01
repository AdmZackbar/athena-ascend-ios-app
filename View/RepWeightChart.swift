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
        let weight: Double
        
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
        let grouped = Dictionary(grouping: data, by: { Key(date: $0.date, reps: $0.reps, weight: $0.weight) })
        if grouped.contains(where: { $0.value.count > 1 }) {
            Chart(grouped.map({ Data(date: $0.key.date, reps: $0.key.reps, weight: $0.key.weight, num: $0.value.count) })
                .sorted(by: { $0.reps < $1.reps })) { d in
                PointMark(x: .value("Date", d.date), y: .value("Weight", d.weight), z: .value("Num", d.num))
                    .symbol(by: .value("Reps", "\(d.reps) reps"))
                    .foregroundStyle(by: .value("Num", d.num))
    //                .symbolSize(by: .value("Num", d.num))
            }
        } else {
            Chart(data.sorted(by: { $0.reps < $1.reps })) { d in
                PointMark(x: .value("Date", d.date), y: .value("Weight", d.weight), z: .value("Num", d.num))
                    .foregroundStyle(by: .value("Reps", "\(d.reps) reps"))
            }
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
        var num: Int
        
        init(date: Date, reps: Int, weight: Double, num: Int = 1) {
            self.id = .init()
            self.date = date
            self.reps = reps
            self.weight = weight
            self.num = num
        }
    }
}

#Preview {
    let date = Date.now
    RepWeightChart(data: [.init(date: date, reps: 3, weight: 40), .init(date: date, reps: 3, weight: 40), .init(date: date, reps: 2, weight: 50)])
}
