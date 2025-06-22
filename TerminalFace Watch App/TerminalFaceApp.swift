//
//  TerminalFaceApp.swift
//  TerminalFace Watch App
//
//  Created by Cyprien on 2025-06-21.
//

import SwiftUI
import HealthKit

let healthStore = HKHealthStore()

@main
struct TerminalFace_Watch_AppApp: App {
    init() {
        requestHealthAuth()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

func requestHealthAuth() {
    let types: Set = [
        HKObjectType.activitySummaryType(),
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    ]
    healthStore.requestAuthorization(toShare: nil, read: types) { _, _ in }
}
