import SwiftUI

/// iPhone 13 Pro Max full-screen control console for the NeuralFeel Watch app.
/// Optimized for the 6.7" Super Retina XDR display with ProMotion.
struct ConsoleView: View {
    @StateObject private var bridge = WatchBridge.shared
    @State private var intensityValue: Double = 0.7
    @State private var selectedProgram: String?

    private let programs = FeelProgram.all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    connectionBanner
                    telemetryPanel
                    programGrid
                    intensitySlider
                    quickActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("NeuralFeel Console")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Sections

    private var connectionBanner: some View {
        HStack {
            Circle()
                .fill(bridge.sessionReachable ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(bridge.sessionReachable ? "Watch Connected" : "Watch Unreachable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Active: \(bridge.activeProgram)")
                .font(.caption)
                .foregroundStyle(bridge.activeProgram == "None" ? .secondary : .primary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var telemetryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Telemetry")
                .font(.headline)

            HStack(spacing: 12) {
                telemetryCard(
                    value: bridge.liveHeartRate > 0 ? "\(Int(bridge.liveHeartRate))" : "--",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )
                telemetryCard(
                    value: bridge.liveHRV > 0 ? "\(Int(bridge.liveHRV)) ms" : "--",
                    unit: "HRV",
                    icon: "waveform.path.ecg",
                    color: .green
                )
                telemetryCard(
                    value: bridge.liveSpO2 > 0 ? "\(Int(bridge.liveSpO2))%" : "--",
                    unit: "SpO2",
                    icon: "lungs.fill",
                    color: .cyan
                )
            }

            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Neural State: ")
                    .foregroundStyle(.secondary)
                Text(bridge.liveNeuralState)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func telemetryCard(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var programGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feel Programs")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(programs) { program in
                    programCard(program)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func programCard(_ program: FeelProgram) -> some View {
        let isSelected = selectedProgram == program.name
        return Button {
            selectedProgram = program.name
            bridge.launchProgram(program.name)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: program.icon)
                        .font(.title2)
                        .foregroundStyle(program.accentColor)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(program.accentColor)
                    }
                }
                Text(program.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(program.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? program.accentColor.opacity(0.18)
                    : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? program.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var intensitySlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Haptic Intensity")
                    .font(.headline)
                Spacer()
                Text("\(Int(intensityValue * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $intensityValue, in: 0.1...1.0, step: 0.05) {
                Text("Intensity")
            } minimumValueLabel: {
                Image(systemName: "waveform").foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "waveform.badge.plus").foregroundStyle(.primary)
            }
            .tint(.purple)
            .onChange(of: intensityValue) { _, v in
                bridge.setIntensity(v)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                actionButton(
                    label: "Neural Reset",
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    color: .purple
                ) {
                    bridge.triggerNeuralReset()
                }

                actionButton(
                    label: "Stop Session",
                    icon: "stop.fill",
                    color: .red
                ) {
                    selectedProgram = nil
                    bridge.stopSession()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ConsoleView()
}
