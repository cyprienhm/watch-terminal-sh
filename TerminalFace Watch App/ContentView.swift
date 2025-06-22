//
//  ContentView.swift
//  TerminalFace Watch App
//
//  Created by Cyprien on 2025-06-21.
//

import SwiftUI
import HealthKit

import HealthKit

struct ActivityRings: Equatable {
    let move: Int
    let exercise: Int
    let stand: Int
}

func fetchRings(completion: @escaping (ActivityRings?) -> Void) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    var components = calendar.dateComponents([.year, .month, .day], from: today)
    components.calendar = calendar
    let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: components, end: components)

    let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
        guard let summary = summaries?.first else {
            completion(nil)
            return
        }

        let move = Int(summary.activeEnergyBurned.doubleValue(for: .kilocalorie()))
        let exercise = Int(summary.appleExerciseTime.doubleValue(for: .minute()))
        let stand = Int(summary.appleStandHours.doubleValue(for: .count()))

        completion(ActivityRings(move: move, exercise: exercise, stand: stand))
    }

    healthStore.execute(query)
}


struct ContentView: View {
    @State private var currentDate = Date()
    @State private var rings = ActivityRings(move: 0, exercise: 0, stand: 0)

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Time:")
                    .foregroundColor(.cyan)
                Text(currentDate.formatted(date: .omitted, time: .shortened))
                    .foregroundColor(.green)
            }
            HStack {
                Text("Date:")
                    .foregroundColor(.cyan)
                Text(currentDate.formatted(date: .long, time: .omitted))
                    .foregroundColor(.green)
            }
            HStack {
                Text("Rings:")
                    .foregroundColor(.cyan)
                Text("\(rings.move) \(rings.exercise) \(rings.stand)")
                    .foregroundColor(.green)
            }
        }
        .font(.system(.body, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .padding()
        .onReceive(timer) { input in
            currentDate = input
        }
        .onAppear {
            fetchRings { result in
                if let result = result {
                    rings = result
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
