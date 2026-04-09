import SwiftUI

/// Root view — first launch asks device role, then routes to Primary or Companion UI.
struct ContentView: View {
    @AppStorage("deviceRole") private var storedRole: String = ""
    @EnvironmentObject var haptic: HapticEngine
    @EnvironmentObject var health: HealthCamera
    @EnvironmentObject var detector: NeuralStateDetector
    @EnvironmentObject var controller: ControllerBridge
    @EnvironmentObject var multipeer: MultipeerBridge
    @EnvironmentObject var webServer: WebConsoleServer

    var body: some View {
        if storedRole.isEmpty {
            rolePicker
        } else if storedRole == "primary" {
            PrimaryView()
        } else {
            CompanionView()
        }
    }

    private var rolePicker: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("NeuralFeel")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text("Choose this device's role")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                roleCard(
                    title: "Primary",
                    subtitle: "iPhone 13 Pro Max",
                    description: "Runs all services · drives DS4 · serves web console to Surface Pro",
                    icon: "iphone",
                    color: .indigo
                ) {
                    storedRole = "primary"
                    multipeer.start(as: .primary, displayName: UIDevice.current.name)
                    webServer.start()
                    controller.startMonitoring()
                    detector.start()
                }

                roleCard(
                    title: "Companion",
                    subtitle: "iPhone 8 Plus",
                    description: "Receives haptic programs from Primary via Multipeer Connectivity",
                    icon: "iphone.gen1",
                    color: .cyan
                ) {
                    storedRole = "companion"
                    multipeer.start(as: .companion, displayName: UIDevice.current.name)
                    detector.start()
                }
            }
        }
        .padding(24)
    }

    private func roleCard(
        title: String,
        subtitle: String,
        description: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(color)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}
