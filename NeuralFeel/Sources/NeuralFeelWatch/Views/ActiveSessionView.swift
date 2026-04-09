import SwiftUI

/// Live feel session view — runs haptics, shows live biometrics, animates neural waveform.
struct ActiveSessionView: View {
    let program: FeelProgram

    @EnvironmentObject var health: HealthMonitor
    @EnvironmentObject var detector: NeuralStateDetector
    @StateObject private var haptic = HapticEngine()
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var wavePhase: Double = 0
    @State private var waveAnimation = false

    var body: some View {
        ZStack {
            adaptiveBackground.ignoresSafeArea()

            VStack(spacing: 10) {
                programHeader
                waveformVisualizer
                biometricRow
                timerLabel
                controlButtons
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopSession() }
        .onChange(of: health.heartRate) { _, hr in
            if isRunning { haptic.updateHeartRate(hr) }
            detector.update(heartRate: hr, hrv: health.hrv)
        }
    }

    // MARK: - Subviews

    private var adaptiveBackground: some View {
        LinearGradient(
            colors: [
                detector.currentState.color.opacity(0.25),
                program.accentColor.opacity(0.15),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 1.2), value: detector.currentState)
    }

    private var programHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: program.icon)
                .foregroundStyle(program.accentColor)
            Text(program.hapticMode.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.0f bpm", program.hapticMode.bpm))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var waveformVisualizer: some View {
        // Simple animated sine-bar waveform to represent haptic rhythm.
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(program.accentColor.opacity(0.85))
                    .frame(
                        width: 4,
                        height: isRunning
                            ? barHeight(index: i)
                            : 4
                    )
                    .animation(
                        isRunning
                            ? .easeInOut(duration: program.hapticMode.intervalSeconds / 2)
                              .repeatForever(autoreverses: true)
                              .delay(Double(i) * 0.05)
                            : .default,
                        value: isRunning
                    )
            }
        }
        .frame(height: 36)
    }

    private var biometricRow: some View {
        HStack(spacing: 12) {
            biometricChip(
                value: health.heartRate > 0 ? "\(Int(health.heartRate))" : "--",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            biometricChip(
                value: health.hrv > 0 ? "\(Int(health.hrv))" : "--",
                unit: "HRV",
                icon: "waveform.path.ecg",
                color: .green
            )
            biometricChip(
                value: health.spo2 > 0 ? "\(Int(health.spo2))%" : "--",
                unit: "SpO2",
                icon: "lungs.fill",
                color: .cyan
            )
        }
    }

    private func biometricChip(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded))
            Text(unit).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var timerLabel: some View {
        Text(formatTime(elapsed))
            .font(.system(size: 18, weight: .medium, design: .monospaced))
            .foregroundStyle(isRunning ? program.accentColor : .secondary)
    }

    private var controlButtons: some View {
        HStack(spacing: 10) {
            Button(action: toggleSession) {
                Label(
                    isRunning ? "Pause" : (elapsed > 0 ? "Resume" : "Start"),
                    systemImage: isRunning ? "pause.fill" : "play.fill"
                )
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(program.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: stopAndDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Session control

    private func toggleSession() {
        if isRunning {
            pauseSession()
        } else {
            startSession()
        }
    }

    private func startSession() {
        isRunning = true
        haptic.start(mode: program.hapticMode, heartRate: health.heartRate)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private func pauseSession() {
        isRunning = false
        haptic.stop()
        timer?.invalidate()
        timer = nil
    }

    private func stopSession() {
        pauseSession()
        elapsed = 0
    }

    private func stopAndDismiss() {
        stopSession()
        dismiss()
    }

    // MARK: - Helpers

    private func barHeight(index: Int) -> CGFloat {
        let phase = Double(index) / 12.0 * 2 * .pi
        return CGFloat(8 + 18 * abs(sin(phase + (elapsed * .pi / program.hapticMode.intervalSeconds))))
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
