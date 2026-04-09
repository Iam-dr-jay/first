import SwiftUI

struct ActiveSessionView: View {
    let program: FeelProgram

    @EnvironmentObject var haptic: HapticEngine
    @EnvironmentObject var health: HealthCamera
    @EnvironmentObject var detector: NeuralStateDetector
    @EnvironmentObject var controller: ControllerBridge
    @EnvironmentObject var multipeer: MultipeerBridge
    @EnvironmentObject var webServer: WebConsoleServer
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var elapsed: TimeInterval = 0
    @State private var ticker: Timer?
    @State private var intensityOverride: Double = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBG.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        programHeader
                        waveform
                        biometricGrid
                        intensityControl
                        ds4Status
                        timerRow
                        controls
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { stopAndDismiss() }
                }
            }
        }
        .onDisappear { stopSession() }
        .onChange(of: health.heartRate) { _, hr in
            if isRunning {
                haptic.syncHeartRate(hr)
                controller.play(mode: program.hapticMode, heartRate: hr)
            }
            detector.update(heartRate: hr, hrv: 0)
            pushTelemetry()
        }
    }

    // MARK: - Background

    private var adaptiveBG: some View {
        LinearGradient(
            colors: [
                detector.currentState.color.opacity(0.18),
                program.accentColor.opacity(0.10),
                Color(.systemBackground)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .animation(.easeInOut(duration: 1.0), value: detector.currentState)
    }

    // MARK: - Subviews

    private var programHeader: some View {
        HStack {
            Image(systemName: program.icon)
                .font(.title2)
                .foregroundStyle(program.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.hapticMode.rawValue)
                    .font(.subheadline).fontWeight(.semibold)
                Text(String(format: "%.0f bpm base", program.hapticMode.bpm))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(detector.currentState.color).frame(width: 8, height: 8)
                Text(detector.currentState.rawValue)
                    .font(.caption).foregroundStyle(detector.currentState.color)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var waveform: some View {
        HStack(spacing: 4) {
            ForEach(0..<18, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(program.accentColor.opacity(0.8))
                    .frame(
                        width: 5,
                        height: isRunning ? waveBarHeight(index: i) : 4
                    )
                    .animation(
                        isRunning
                            ? .easeInOut(duration: program.hapticMode.intervalSeconds / 2)
                              .repeatForever(autoreverses: true)
                              .delay(Double(i) * 0.04)
                            : .easeInOut(duration: 0.3),
                        value: isRunning
                    )
            }
        }
        .frame(height: 48)
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var biometricGrid: some View {
        HStack(spacing: 10) {
            biometricTile(
                value: health.heartRate > 0 ? "\(Int(health.heartRate))" : "--",
                unit: "BPM", icon: "heart.fill", color: .red
            )
            biometricTile(
                value: String(format: "%.2f g", detector.motionMagnitude),
                unit: "Motion", icon: "figure.walk", color: .orange
            )
            biometricTile(
                value: detector.currentState.rawValue,
                unit: "Neural", icon: detector.currentState.icon,
                color: detector.currentState.color
            )
        }
    }

    private func biometricTile(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var intensityControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Haptic Intensity")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("\(Int(intensityOverride * 100))%")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $intensityOverride, in: 0.1...1.0)
                .tint(program.accentColor)
                .onChange(of: intensityOverride) { _, v in
                    multipeer.send(command: ["command": "intensity", "value": v])
                    webServer.push(telemetry: ["ds4Left": controller.leftMotorLevel,
                                               "ds4Right": controller.rightMotorLevel])
                }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var ds4Status: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(controller.isConnected ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(controller.isConnected ? controller.controllerName : "DualShock 4 not connected")
                .font(.caption)
                .foregroundStyle(controller.isConnected ? .primary : .secondary)
            Spacer()
            if controller.isConnected && isRunning {
                HStack(spacing: 6) {
                    motorBar(value: controller.leftMotorLevel, color: .orange, label: "L")
                    motorBar(value: controller.rightMotorLevel, color: .cyan, label: "R")
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func motorBar(value: Float, color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(Color(.systemFill))
                    .frame(width: 10, height: 24)
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: 10, height: CGFloat(value) * 24)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
    }

    private var timerRow: some View {
        Text(formatTime(elapsed))
            .font(.system(size: 36, weight: .light, design: .monospaced))
            .foregroundStyle(isRunning ? program.accentColor : .secondary)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: toggleSession) {
                Label(
                    isRunning ? "Pause" : (elapsed > 0 ? "Resume" : "Start"),
                    systemImage: isRunning ? "pause.fill" : "play.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(program.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button(action: stopAndDismiss) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Session control

    private func toggleSession() {
        isRunning ? pauseSession() : startSession()
    }

    private func startSession() {
        isRunning = true
        haptic.start(mode: program.hapticMode, heartRate: health.heartRate)
        controller.play(mode: program.hapticMode, heartRate: health.heartRate)
        multipeer.send(command: ["command": "launch", "program": program.name])
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsed += 1 }
        pushTelemetry()
    }

    private func pauseSession() {
        isRunning = false
        haptic.stop()
        controller.stopHaptics()
        ticker?.invalidate(); ticker = nil
        pushTelemetry()
    }

    private func stopSession() {
        pauseSession()
        elapsed = 0
    }

    private func stopAndDismiss() {
        stopSession()
        multipeer.send(command: ["command": "stop"])
        dismiss()
    }

    // MARK: - Helpers

    private func waveBarHeight(index: Int) -> CGFloat {
        let phase = Double(index) / 18.0 * 2 * .pi
        let t = elapsed * .pi / program.hapticMode.intervalSeconds
        return CGFloat(8 + 28 * abs(sin(phase + t)))
    }

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }

    private func pushTelemetry() {
        webServer.push(telemetry: [
            "heartRate": health.heartRate,
            "neuralState": detector.currentState.rawValue,
            "confidence": detector.confidence,
            "activeProgram": isRunning ? program.name : "None",
            "ds4Connected": controller.isConnected,
            "ds4Left": controller.leftMotorLevel,
            "ds4Right": controller.rightMotorLevel,
            "companionConnected": !multipeer.connectedPeers.isEmpty
        ])
    }
}
