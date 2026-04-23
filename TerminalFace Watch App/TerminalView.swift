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

enum TimerState: Equatable {
    case idle
    case running(since: Date, accumulated: TimeInterval)
    case paused(accumulated: TimeInterval)

    func elapsed(at now: Date) -> TimeInterval {
        switch self {
        case .idle: return 0
        case .running(let since, let accumulated):
            return accumulated + now.timeIntervalSince(since)
        case .paused(let accumulated):
            return accumulated
        }
    }
}

func formatElapsed(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, sec)
    }
    return String(format: "%02d:%02d", m, sec)
}

struct TerminalView: View {
    @State private var health: HealthService
    @State private var weather: WeatherService
    @State private var batteryLevel: Double
    @State private var timerState: TimerState = .idle
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
                    PromptRow(command: Text("now").foregroundColor(Dracula.foreground))
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
                    bottomRow(date: context.date, showCursor: showCursor)
                }
                .font(.system(size: 14, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .foregroundStyle(isLuminanceReduced ? Dracula.comment : Dracula.foreground)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 3) { timerState = .idle }
            .onTapGesture(count: 2) { resetTimer() }
            .onTapGesture { toggleTimer(now: context.date) }
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

    private func bottomRow(date: Date, showCursor: Bool) -> some View {
        if case .idle = timerState {
            let cursor = showCursor ? "█" : ""
            return PromptRow(command: Text(cursor).foregroundColor(Dracula.foreground))
        }
        let elapsed = formatElapsed(Int(timerState.elapsed(at: date)))
        let label = isRunning ? "timer  " : "paused "
        let labelColor = isRunning ? Dracula.cyan : Dracula.comment
        return PromptRow(
            prefix: Text(""),
            command: Text(label).foregroundColor(labelColor)
                + Text(elapsed).foregroundColor(Dracula.foreground)
        )
    }

    private var isRunning: Bool {
        if case .running = timerState { return true }
        return false
    }

    private func toggleTimer(now: Date) {
        switch timerState {
        case .idle:
            timerState = .running(since: now, accumulated: 0)
        case .running(let since, let accumulated):
            timerState = .paused(accumulated: accumulated + now.timeIntervalSince(since))
        case .paused(let accumulated):
            timerState = .running(since: now, accumulated: accumulated)
        }
    }

    private func resetTimer() {
        if case .idle = timerState { return }
        timerState = .paused(accumulated: 0)
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
    let prefix: Text
    let command: Text

    init(prefix: Text = Self.defaultPrefix, command: Text) {
        self.prefix = prefix
        self.command = command
    }

    static var defaultPrefix: Text {
        Text(TerminalConstants.shellPrefix).foregroundColor(Dracula.green)
            + Text("~").foregroundColor(Dracula.cyan)
            + Text("$ ").foregroundColor(Dracula.foreground)
    }

    var body: some View {
        HStack(spacing: 0) {
            prefix + command
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
