//
//  TerminalFaceApp.swift
//  TerminalFace Watch App
//
//  Created by Cyprien on 2025-06-21.
//

import SwiftUI

@main
struct TerminalFaceApp: App {
    @State private var health = HealthService()
    @State private var weather = WeatherService()

    var body: some Scene {
        WindowGroup {
            TerminalView(health: health, weather: weather)
        }
    }
}
