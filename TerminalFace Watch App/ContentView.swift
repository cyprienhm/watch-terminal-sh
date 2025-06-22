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
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: String = "--°C"
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        fetchTemperature(for: loc)
        locationManager.stopUpdatingLocation()
    }

    func fetchTemperature(for location: CLLocation) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current_weather=true&temperature_unit=celsius"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current_weather"] as? [String: Any],
                  let temp = current["temperature"] as? Double else { return }

            DispatchQueue.main.async {
                self.temperature = "\(Int(temp))°C"
            }
        }.resume()
    }
}

func fetchSteps(completion: @escaping (Int) -> Void) {
    let store = HKHealthStore()
    let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

    let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
        guard let sum = result?.sumQuantity() else {
            completion(0)
            return
        }
        completion(Int(sum.doubleValue(for: HKUnit.count())))
    }
    store.execute(query)
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
let stepFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f
}()

func formatSteps(_ value: Int) -> String {
    stepFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

struct ContentView: View {
    @State private var currentDate = Date()
    @State private var rings = ActivityRings(move: 0, exercise: 0, stand: 0)
    @State private var steps = 0
    @StateObject private var weatherManager = WeatherManager()
    @State private var batteryLevel = 0
    @State private var showCursor = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let fastTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("cy@watch:")
                    .foregroundColor(.green) +
                Text("~")
                    .foregroundColor(.blue)
                Text("$")
                    .foregroundColor(.white)
                Text("now")
                    .foregroundColor(.white)
            }
            HStack {
                Text("Time:")
                    .foregroundColor(.cyan)
                Text(currentDate.formatted(date: .omitted, time: .shortened))
                    .foregroundColor(.white)
            }
            HStack {
                Text("Date:")
                    .foregroundColor(.cyan)
                Text(currentDate.formatted(
                    Date.FormatStyle()
                        .month(.abbreviated)
                        .day(.twoDigits)
                        .weekday(.abbreviated)
                ))
                .foregroundColor(.white)
            }
            HStack {
                Text("Rings:")
                    .foregroundColor(.cyan)
                Text("\(rings.move)")
                    .foregroundColor(.red)
                Text("-")
                    .foregroundColor(.white)
                Text("\(rings.exercise)")
                    .foregroundColor(.green)
                Text("-")
                    .foregroundColor(.white)
                Text("\(rings.stand)")
                    .foregroundColor(.blue)
            }
            HStack {
                Text("Temp:")
                    .foregroundColor(.cyan)
                Text(weatherManager.temperature)
                    .foregroundColor(.white)
            }
            HStack {
                Text("Steps:")
                    .foregroundColor(.cyan)
                Text(formatSteps(steps))
                    .foregroundColor(.white)
            }
            HStack {
                Text("Battery:")
                    .foregroundColor(.cyan)
                Text("\(batteryLevel)%")
                    .foregroundColor(.white)
            }
            HStack {
                Text("cy@watch:")
                    .foregroundColor(.green) +
                Text("~")
                    .foregroundColor(.blue)
                Text("$")
                    .foregroundColor(.white)
                if showCursor {
                    Text("█")
                        .foregroundColor(.white)
                        .opacity(0.8)
                }
            }
        }
        .font(.system(size: 14, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .padding()
        .onReceive(timer) { input in
            currentDate = input
            batteryLevel = Int(WKInterfaceDevice.current().batteryLevel * 100)
            fetchRings { result in
                if let result = result {
                    rings = result
                }
            }
            showCursor.toggle()
            fetchSteps { value in
                steps = value
            }
        }
        .onAppear {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
            batteryLevel = Int(WKInterfaceDevice.current().batteryLevel * 100)
        }
    }
}

#Preview {
    ContentView()
}
