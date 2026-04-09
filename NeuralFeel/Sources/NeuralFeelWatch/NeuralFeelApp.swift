import SwiftUI

@main
struct NeuralFeelApp: App {
    @StateObject private var health   = HealthMonitor()
    @StateObject private var detector = NeuralStateDetector()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(health)
                .environmentObject(detector)
                .onAppear { detector.start() }
                .onDisappear { detector.stop() }
        }
    }
}
