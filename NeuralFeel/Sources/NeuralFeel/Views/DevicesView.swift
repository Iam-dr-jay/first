import SwiftUI

/// Shows status of all connected devices and lets user copy the console URL.
struct DevicesView: View {
    @EnvironmentObject var controller: ControllerBridge
    @EnvironmentObject var multipeer: MultipeerBridge
    @EnvironmentObject var webServer: WebConsoleServer
    @State private var urlCopied = false

    var body: some View {
        NavigationStack {
            List {
                Section("This Device") {
                    deviceRow(
                        name: UIDevice.current.name,
                        subtitle: "iPhone 13 Pro Max · Primary",
                        icon: "iphone",
                        color: .indigo,
                        connected: true
                    )
                }

                Section("iPhone 8 Plus") {
                    deviceRow(
                        name: multipeer.isConnected ? (multipeer.connectedPeers.first ?? "8 Plus") : "Searching…",
                        subtitle: multipeer.isConnected ? "Companion · Multipeer synced" : "Not found — open NeuralFeel on iPhone 8 Plus",
                        icon: "iphone.gen1",
                        color: .cyan,
                        connected: multipeer.isConnected
                    )
                }

                Section("DualShock 4") {
                    deviceRow(
                        name: controller.controllerName,
                        subtitle: controller.isConnected ? "Bluetooth · haptics active" : "Pair via Settings → Bluetooth",
                        icon: "gamecontroller.fill",
                        color: .blue,
                        connected: controller.isConnected
                    )
                    if controller.isConnected {
                        HStack {
                            motorMeter(label: "Left Motor", value: controller.leftMotorLevel, color: .orange)
                            motorMeter(label: "Right Motor", value: controller.rightMotorLevel, color: .cyan)
                        }
                    }
                }

                Section("Surface Pro 6 Console") {
                    VStack(alignment: .leading, spacing: 8) {
                        deviceRow(
                            name: "Web Console",
                            subtitle: webServer.isRunning ? "Open in Edge/Chrome on Surface Pro" : "Starting…",
                            icon: "laptopcomputer",
                            color: .purple,
                            connected: webServer.isRunning
                        )
                        if webServer.isRunning {
                            Button {
                                UIPasteboard.general.string = webServer.serverURL
                                urlCopied = true
                                Task { try? await Task.sleep(for: .seconds(2)); urlCopied = false }
                            } label: {
                                HStack {
                                    Text(webServer.serverURL)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                                        .foregroundStyle(urlCopied ? .green : .secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func deviceRow(name: String, subtitle: String, icon: String, color: Color, connected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(connected ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }

    private func motorMeter(label: String, value: Float, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(value), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: value)
                }
            }
            .frame(height: 6)
            Text("\(Int(value * 100))%").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
