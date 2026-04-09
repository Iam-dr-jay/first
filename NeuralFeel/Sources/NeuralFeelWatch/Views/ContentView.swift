import SwiftUI

/// Root tab view switching between the live dashboard and feel programs.
struct ContentView: View {
    @EnvironmentObject var health: HealthMonitor

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "waveform.path.ecg") }

            FeelProgramsView()
                .tabItem { Label("Programs", systemImage: "bolt.heart.fill") }
        }
        .task {
            await health.requestAuthorization()
        }
    }
}
