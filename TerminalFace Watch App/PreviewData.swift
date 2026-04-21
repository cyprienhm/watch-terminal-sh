#if DEBUG
import SwiftUI

@MainActor
extension HealthService {
    static var preview: HealthService {
        HealthService(
            steps: 5471,
            rings: ActivityRings(move: 418, exercise: 6, stand: 8)
        )
    }
}

@MainActor
extension WeatherService {
    static var preview: WeatherService {
        WeatherService(temperature: "21°C")
    }
}

#Preview {
    TerminalView(health: .preview, weather: .preview, previewBattery: 0.76)
}
#endif
