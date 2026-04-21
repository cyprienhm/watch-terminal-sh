import Foundation
import HealthKit
import Observation

struct ActivityRings: Equatable {
    let move: Int
    let exercise: Int
    let stand: Int

    static let zero = ActivityRings(move: 0, exercise: 0, stand: 0)
}

@Observable
@MainActor
final class HealthService {
    var steps: Int = 0
    var rings: ActivityRings = .zero

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.activitySummaryType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
    }

    init(steps: Int = 0, rings: ActivityRings = .zero) {
        self.steps = steps
        self.rings = rings
    }

    func requestAuthorization() {
        store.requestAuthorization(toShare: nil, read: readTypes) { _, _ in }
    }

    func refresh() {
        fetchSteps()
        fetchRings()
    }

    private func fetchSteps() {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            Task { @MainActor [weak self] in
                self?.steps = Int(value)
            }
        }
        store.execute(query)
    }

    private func fetchRings() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.calendar = calendar
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: components, end: components)

        let query = HKActivitySummaryQuery(predicate: predicate) { [weak self] _, summaries, _ in
            guard let summary = summaries?.first else { return }
            let next = ActivityRings(
                move: Int(summary.activeEnergyBurned.doubleValue(for: .kilocalorie())),
                exercise: Int(summary.appleExerciseTime.doubleValue(for: .minute())),
                stand: Int(summary.appleStandHours.doubleValue(for: .count()))
            )
            Task { @MainActor [weak self] in
                self?.rings = next
            }
        }
        store.execute(query)
    }
}
