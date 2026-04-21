import SwiftUI
import WatchKit

enum TerminalConstants {
    static let batteryBarLength = 7
    static let shellPrefix = "me@watch:"
    static let timeLocale = Locale(identifier: "en_US")
    static let dataRefreshInterval: TimeInterval = 60
}

private let stepFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f
}()

func formatSteps(_ value: Int) -> String {
    stepFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

func batteryBar(level: Double, length: Int = TerminalConstants.batteryBarLength) -> String {
    let clamped = max(0, min(1, level))
    let filled = Int(clamped * Double(length))
    let empty = length - filled - 1
    if empty < 0 { return String(repeating: "#", count: length) }
    return String(repeating: "#", count: filled) + ">" + String(repeating: "-", count: empty)
}

struct TerminalView: View {
    @State private var health: HealthService
    @State private var weather: WeatherService
    @State private var batteryLevel: Double
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private let previewBattery: Double?

    private let dataTick = Timer.publish(
        every: TerminalConstants.dataRefreshInterval,
        on: .main,
        in: .common
    ).autoconnect()

    init(
        health: HealthService,
        weather: WeatherService,
        previewBattery: Double? = nil
    ) {
        self._health = State(wrappedValue: health)
        self._weather = State(wrappedValue: weather)
        self._batteryLevel = State(wrappedValue: previewBattery ?? 0)
        self.previewBattery = previewBattery
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let showCursor = !isLuminanceReduced
                && Int(context.date.timeIntervalSince1970) % 2 == 0

            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 4) {
                    PromptRow(command: "now")
                    InfoRow(label: "Time:", value: timeString(context.date))
                    InfoRow(label: "Date:", value: dateString(context.date))
                    RingsRow(rings: health.rings)
                    InfoRow(label: "Temp:", value: weather.temperature, valueColor: Dracula.orange)
                    InfoRow(label: "Steps:", value: formatSteps(health.steps))
                    InfoRow(
                        label: "Bat:",
                        value: "\(Int(100 * batteryLevel))% [\(batteryBar(level: batteryLevel))]",
                        valueColor: Dracula.pink
                    )
                    PromptRow(command: showCursor ? "█" : nil)
                }
                .font(.system(size: 14, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .foregroundStyle(isLuminanceReduced ? Dracula.comment : Dracula.foreground)
            }
        }
        .onAppear {
            guard previewBattery == nil else { return }
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
            health.requestAuthorization()
            refreshAll()
        }
        .onReceive(dataTick) { _ in
            guard previewBattery == nil, !isLuminanceReduced else { return }
            refreshAll()
        }
    }

    private func refreshAll() {
        let level = Double(WKInterfaceDevice.current().batteryLevel)
        if level >= 0 { batteryLevel = level }
        health.refresh()
        weather.refresh()
    }

    private func timeString(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute(.twoDigits)
                .locale(TerminalConstants.timeLocale)
        )
    }

    private func dateString(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day(.twoDigits)
                .weekday(.abbreviated)
        )
    }
}

private struct PromptRow: View {
    let command: String?

    var body: some View {
        HStack(spacing: 0) {
            Text(TerminalConstants.shellPrefix).foregroundColor(Dracula.green)
                + Text("~").foregroundColor(Dracula.cyan)
                + Text("$ ").foregroundColor(Dracula.foreground)
                + Text(command ?? "").foregroundColor(Dracula.foreground)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = Dracula.foreground

    var body: some View {
        HStack {
            Text(label).foregroundColor(Dracula.cyan)
            Text(value).foregroundColor(valueColor)
        }
    }
}

private struct RingsRow: View {
    let rings: ActivityRings

    var body: some View {
        HStack {
            Text("Rings:").foregroundColor(Dracula.cyan)
            Text("\(rings.move)").foregroundColor(Dracula.red)
            Text("-").foregroundColor(Dracula.foreground)
            Text("\(rings.exercise)").foregroundColor(Dracula.green)
            Text("-").foregroundColor(Dracula.foreground)
            Text("\(rings.stand)").foregroundColor(Dracula.cyan)
        }
    }
}
