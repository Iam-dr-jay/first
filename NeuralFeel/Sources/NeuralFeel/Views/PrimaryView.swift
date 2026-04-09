import SwiftUI

/// Main UI for iPhone 13 Pro Max — full tab layout with dashboard, programs, and devices.
struct PrimaryView: View {
    @EnvironmentObject var webServer: WebConsoleServer

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "waveform.path.ecg") }

            FeelProgramsView()
                .tabItem { Label("Programs", systemImage: "bolt.heart.fill") }

            DevicesView()
                .tabItem { Label("Devices", systemImage: "network") }
        }
        .overlay(alignment: .bottom) {
            if webServer.isRunning {
                consoleBadge
            }
        }
    }

    private var consoleBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(.green).frame(width: 7, height: 7)
            Text("Console: \(webServer.serverURL)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 60)
    }
}
