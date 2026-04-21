import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class WeatherService: NSObject {
    var temperature: String = "--°C"

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var inFlight = false

    private static let urlTemplate =
        "https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f&current_weather=true&temperature_unit=celsius"

    init(temperature: String = "--°C") {
        self.temperature = temperature
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
    }

    func refresh() {
        guard !inFlight else { return }
        inFlight = true
        locationManager.startUpdatingLocation()
    }

    private func fetchTemperature(for location: CLLocation) {
        let urlString = String(
            format: Self.urlTemplate,
            location.coordinate.latitude,
            location.coordinate.longitude
        )
        guard let url = URL(string: urlString) else {
            inFlight = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            defer { Task { @MainActor [weak self] in self?.inFlight = false } }
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let current = json["current_weather"] as? [String: Any],
                let temp = current["temperature"] as? Double
            else { return }

            Task { @MainActor [weak self] in
                self?.temperature = "\(Int(temp.rounded()))°C"
            }
        }.resume()
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        manager.stopUpdatingLocation()
        Task { @MainActor [weak self] in
            self?.fetchTemperature(for: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        Task { @MainActor [weak self] in
            self?.inFlight = false
        }
    }
}
