import SwiftUI

/// Live biometric dashboard — heart rate gauge, neural state badge, HRV & SpO2.
struct DashboardView: View {
    @EnvironmentObject var health: HealthMonitor
    @EnvironmentObject var detector: NeuralStateDetector

    // Animated HR pulse scale
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                neuralStateBadge
                heartRateGauge
                secondaryMetrics
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Neural Feed")
        .onChange(of: health.heartRate) { _, _ in
            triggerPulse()
            detector.update(heartRate: health.heartRate, hrv: health.hrv)
        }
    }

    // MARK: - Subviews

    private var neuralStateBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: detector.currentState.icon)
                .foregroundStyle(detector.currentState.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(detector.currentState.rawValue)
                    .font(.headline)
                    .foregroundStyle(detector.currentState.color)
                Text(detector.currentState.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(10)
        .background(detector.currentState.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.5), value: detector.currentState)
    }

    private var heartRateGauge: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: hrFraction)
                .stroke(
                    AngularGradient(
                        colors: [.red, .orange, .yellow],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: health.heartRate)

            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .scaleEffect(pulse ? 1.25 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: pulse)
                Text(health.heartRate > 0 ? "\(Int(health.heartRate))" : "--")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }

    private var secondaryMetrics: some View {
        HStack(spacing: 8) {
            metricTile(
                value: health.hrv > 0 ? String(format: "%.0f ms", health.hrv) : "--",
                label: "HRV",
                icon: "waveform.path.ecg",
                color: .green
            )
            metricTile(
                value: health.spo2 > 0 ? String(format: "%.0f%%", health.spo2) : "--",
                label: "SpO2",
                icon: "lungs.fill",
                color: .cyan
            )
        }
    }

    private func metricTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private var hrFraction: Double {
        guard health.heartRate > 0 else { return 0 }
        return min(1.0, (health.heartRate - 40) / 160)
    }

    private func triggerPulse() {
        pulse = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            pulse = false
        }
    }
}
