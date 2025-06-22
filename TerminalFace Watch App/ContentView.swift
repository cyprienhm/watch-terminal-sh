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
    func refresh() {
        locationManager.startUpdatingLocation()
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

struct Dracula {
    static let background = Color(red: 40/255, green: 42/255, blue: 54/255)
    static let currentLine = Color(red: 68/255, green: 71/255, blue: 90/255)
    static let foreground = Color(red: 248/255, green: 248/255, blue: 242/255)
    static let comment = Color(red: 98/255, green: 114/255, blue: 164/255)
    static let cyan = Color(red: 139/255, green: 233/255, blue: 253/255)
    static let green = Color(red: 80/255, green: 250/255, blue: 123/255)
    static let orange = Color(red: 255/255, green: 184/255, blue: 108/255)
    static let pink = Color(red: 255/255, green: 121/255, blue: 198/255)
    static let purple = Color(red: 189/255, green: 147/255, blue: 249/255)
    static let red = Color(red: 255/255, green: 85/255, blue: 85/255)
    static let yellow = Color(red: 241/255, green: 250/255, blue: 140/255)
}


struct ContentView: View {
    @State private var currentDate = Date()
    @State private var rings = ActivityRings(move: 0, exercise: 0, stand: 0)
    @State private var steps = 0
    @StateObject private var weatherManager = WeatherManager()
    @State private var batteryLevel = 0.0
    @State private var showCursor = true
    
    let batteryBarLength = 7
    
    var batteryBar: String {
        let filled = Int(batteryLevel  * Double(batteryBarLength))
        let empty = batteryBarLength - filled - 1
        if empty < 0 { return String(repeating: "#", count: batteryBarLength) }
        return String(repeating: "#", count: filled) + ">" + String(repeating: "-", count: empty)
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let slowTimer = Timer.publish(every: 600, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("cy@watch:")
                    .foregroundColor(Dracula.green) +
                Text("~")
                    .foregroundColor(Dracula.cyan)
                Text("$")
                    .foregroundColor(Dracula.foreground)
                Text("now")
                    .foregroundColor(Dracula.foreground)
            }
            HStack {
                Text("Time:")
                    .foregroundColor(Dracula.cyan)
                Text(currentDate.formatted(
                    Date.FormatStyle()
                        .hour(.defaultDigits(amPM: .abbreviated))
                        .minute(.twoDigits)
                        .locale(Locale(identifier: "en_US"))
                ))

            }
            HStack {
                Text("Date:")
                    .foregroundColor(Dracula.cyan)
                Text(currentDate.formatted(
                    Date.FormatStyle()
                        .month(.abbreviated)
                        .day(.twoDigits)
                        .weekday(.abbreviated)
                ))
                .foregroundColor(Dracula.foreground)
            }
            HStack {
                Text("Rings:")
                    .foregroundColor(Dracula.cyan)
                Text("\(rings.move)")
                    .foregroundColor(.red)
                Text("-")
                    .foregroundColor(Dracula.foreground)
                Text("\(rings.exercise)")
                    .foregroundColor(Dracula.green)
                Text("-")
                    .foregroundColor(Dracula.foreground)
                Text("\(rings.stand)")
                    .foregroundColor(Dracula.cyan)
            }
            HStack {
                Text("Temp:")
                    .foregroundColor(Dracula.cyan)
                Text(weatherManager.temperature)
                    .foregroundColor(Dracula.orange)
            }
            HStack {
                Text("Steps:")
                    .foregroundColor(Dracula.cyan)
                Text(formatSteps(steps))
                    .foregroundColor(Dracula.foreground)
            }
            HStack {
                Text("Bat:")
                    .foregroundColor(Dracula.cyan)
                Text("\(Int(100 * batteryLevel))%")
                    .foregroundColor(Dracula.foreground)
                Text("[\(batteryBar)]")
                    .foregroundColor(Dracula.pink)
            }
            HStack {
                Text("cy@watch:")
                    .foregroundColor(Dracula.green) +
                Text("~")
                    .foregroundColor(Dracula.cyan)
                Text("$")
                    .foregroundColor(Dracula.foreground)
                if showCursor {
                    Text("█")
                        .foregroundColor(Dracula.foreground)
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
            batteryLevel = Double(WKInterfaceDevice.current().batteryLevel)
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
        .onReceive(slowTimer) { input in
            weatherManager.refresh()
        }
        .onAppear {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        }
    }
}

#Preview {
    ContentView()
}
