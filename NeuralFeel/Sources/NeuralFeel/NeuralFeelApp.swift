import SwiftUI

@main
struct NeuralFeelApp: App {
    @StateObject private var haptic     = HapticEngine()
    @StateObject private var health     = HealthCamera()
    @StateObject private var detector   = NeuralStateDetector()
    @StateObject private var controller = ControllerBridge()
    @StateObject private var multipeer  = MultipeerBridge()
    @StateObject private var webServer  = WebConsoleServer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(haptic)
                .environmentObject(health)
                .environmentObject(detector)
                .environmentObject(controller)
                .environmentObject(multipeer)
                .environmentObject(webServer)
        }
    }
}
