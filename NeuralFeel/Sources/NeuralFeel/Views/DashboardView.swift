import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthCamera
    @EnvironmentObject var detector: NeuralStateDetector
    @EnvironmentObject var webServer: WebConsoleServer

    @State private var cameraActive = false
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    neuralStateBanner
                    heartRateSection
                    cameraToggle
                    secondaryMetrics
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: health.heartRate) { _, hr in
            if hr > 0 { triggerPulse() }
            detector.update(heartRate: hr, hrv: 0)
            pushTelemetry()
        }
        .onChange(of: detector.currentState) { _, _ in pushTelemetry() }
    }

    // MARK: - Neural state banner

    private var neuralStateBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(detector.currentState.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: detector.currentState.icon)
                    .font(.title3)
                    .foregroundStyle(detector.currentState.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(detector.currentState.rawValue)
                    .font(.headline)
                    .foregroundStyle(detector.currentState.color)
                Text(detector.currentState.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Confidence dots
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Double(i) < detector.confidence * 5 ? detector.currentState.color : Color(.systemFill))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(14)
        .background(detector.currentState.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(detector.currentState.color.opacity(0.15)))
        .animation(.easeInOut(duration: 0.5), value: detector.currentState)
    }

    // MARK: - Heart rate

    private var heartRateSection: some View {
        HStack(spacing: 16) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: hrFraction)
                    .stroke(
                        AngularGradient(colors: [.red, .orange, .yellow], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: health.heartRate)
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.25), value: pulse)
                    Text(health.heartRate > 0 ? "\(Int(health.heartRate))" : "--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                if health.heartRate > 0 {
                    Label("Live from camera", systemImage: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Tap camera to start", systemImage: "camera")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if health.isReading {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signal quality")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemFill)).frame(height: 6)
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: geo.size.width * health.signalQuality, height: 6)
                                    .animation(.easeInOut, value: health.signalQuality)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var cameraToggle: some View {
        Button {
            cameraActive.toggle()
            Task {
                if cameraActive { await health.start() }
                else { health.stop() }
            }
        } label: {
            HStack {
                Image(systemName: cameraActive ? "camera.fill" : "camera")
                    .foregroundStyle(cameraActive ? .green : .primary)
                Text(cameraActive ? "Camera HR · Active" : "Start Camera Heart Rate")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(14)
            .background(
                cameraActive ? Color.green.opacity(0.1) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cameraActive ? Color.green.opacity(0.3) : Color.clear)
            )
        }
        .foregroundStyle(.primary)
    }

    private var secondaryMetrics: some View {
        HStack(spacing: 12) {
            motionCard
        }
    }

    private var motionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Motion", systemImage: "figure.walk")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.2f", detector.motionMagnitude))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var hrFraction: Double {
        guard health.heartRate > 0 else { return 0 }
        return min(1.0, (health.heartRate - 40) / 160)
    }

    private func triggerPulse() {
        pulse = true
        Task { try? await Task.sleep(for: .milliseconds(250)); pulse = false }
    }

    private func pushTelemetry() {
        webServer.push(telemetry: [
            "heartRate": health.heartRate,
            "hrv": 0,
            "spo2": 0,
            "neuralState": detector.currentState.rawValue,
            "confidence": detector.confidence
        ])
    }
}
