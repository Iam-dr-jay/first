import SwiftUI

/// Simple UI for iPhone 8 Plus — shows connection status and mirrors active feel program.
struct CompanionView: View {
    @EnvironmentObject var haptic: HapticEngine
    @EnvironmentObject var detector: NeuralStateDetector
    @EnvironmentObject var multipeer: MultipeerBridge
    @EnvironmentObject var health: HealthCamera

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                connectionCard
                if haptic.isRunning {
                    activeCard
                } else {
                    waitingCard
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("NeuralFeel")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { multipeer.onCommand = handleCommand }
    }

    // MARK: - Subviews

    private var connectionCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(multipeer.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(multipeer.isConnected ? "Connected to Primary" : "Searching for Primary…")
                    .font(.subheadline).fontWeight(.medium)
                if multipeer.isConnected {
                    Text(multipeer.connectedPeers.first ?? "")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var waitingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("Waiting for program")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Launch a feel program from the Primary device or the Surface console.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var activeCard: some View {
        VStack(spacing: 12) {
            if let mode = haptic.currentMode,
               let program = FeelProgram.all.first(where: { $0.hapticMode == mode }) {
                Image(systemName: program.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(program.accentColor)
                Text(program.name)
                    .font(.title2).fontWeight(.bold)
                Text(program.subtitle)
                    .font(.subheadline).foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(program.accentColor)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                        .scaleEffect(haptic.isRunning ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: haptic.isRunning)
                    Text("Haptics running")
                        .font(.caption)
                        .foregroundStyle(program.accentColor)
                }

                Button("Stop") { haptic.stop() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Multipeer command handler

    private func handleCommand(_ cmd: [String: Any]) {
        guard let command = cmd["command"] as? String else { return }
        switch command {
        case "launch":
            if let name = cmd["program"] as? String,
               let program = FeelProgram.all.first(where: { $0.name == name }) {
                haptic.start(mode: program.hapticMode, heartRate: health.heartRate)
            }
        case "stop":
            haptic.stop()
        case "neuralReset":
            haptic.start(mode: .neuralReset, heartRate: 0)
        case "intensity":
            // Intensity is managed by HapticEngine internally via re-launch
            break
        default:
            break
        }
    }
}
