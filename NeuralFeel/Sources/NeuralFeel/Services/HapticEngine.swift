import Foundation
import CoreHaptics
import UIKit

/// Drives the iPhone Taptic Engine via Core Haptics.
/// ControllerBridge drives the DS4 motors separately and mirrors the same program.
@MainActor
final class HapticEngine: ObservableObject {

    @Published var isRunning = false
    @Published var currentMode: FeelProgram.HapticMode?

    private var engine: CHHapticEngine?
    private var pulseTask: Task<Void, Never>?

    init() { setupEngine() }

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in self?.setupEngine() }
            }
            try engine?.start()
        } catch {
            print("[HapticEngine] init error: \(error)")
        }
    }

    // MARK: - Control

    func start(mode: FeelProgram.HapticMode, heartRate: Double) {
        stop()
        currentMode = mode
        isRunning = true
        switch mode {
        case .energyBoost: runEnergyBoost(hr: heartRate)
        case .calmFlow:    runCalmFlow()
        case .focusLock:   runFocusLock(hr: heartRate)
        case .neuralReset: runNeuralReset()
        }
    }

    func syncHeartRate(_ hr: Double) {
        guard isRunning, let mode = currentMode else { return }
        switch mode {
        case .energyBoost: runEnergyBoost(hr: hr)
        case .focusLock:   runFocusLock(hr: hr)
        default: break
        }
    }

    func stop() {
        pulseTask?.cancel()
        pulseTask = nil
        isRunning = false
        currentMode = nil
    }

    // MARK: - Programs

    private func runEnergyBoost(hr: Double) {
        pulseTask?.cancel()
        let bpm = max(90, min(160, hr > 0 ? hr : 120))
        let interval = 60.0 / bpm
        pulseTask = Task {
            var phase = 0
            while !Task.isCancelled {
                let intensity = Float(min(0.4 + Double(phase % 4) * 0.15, 1.0))
                fire(intensity: intensity, sharpness: 0.8)
                try? await Task.sleep(for: .seconds(interval))
                phase += 1
            }
        }
    }

    private func runCalmFlow() {
        pulseTask = Task {
            var t = 0.0
            while !Task.isCancelled {
                let intensity = Float(0.2 + 0.6 * (sin(t * .pi) + 1) / 2)
                let sharpness = Float(0.25 + 0.35 * (1 - sin(t * .pi)))
                fire(intensity: intensity, sharpness: sharpness)
                try? await Task.sleep(for: .seconds(1.0))
                t += 1
            }
        }
    }

    private func runFocusLock(hr: Double) {
        pulseTask?.cancel()
        let bpm = max(70, min(100, hr > 0 ? hr : 80))
        let interval = 60.0 / bpm
        pulseTask = Task {
            while !Task.isCancelled {
                fire(intensity: 0.6, sharpness: 0.7)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func runNeuralReset() {
        guard let engine else { return }
        pulseTask = Task {
            while !Task.isCancelled {
                playResetPattern(engine: engine)
                try? await Task.sleep(for: .seconds(3.0))
            }
        }
    }

    // MARK: - Primitives

    private func fire(intensity: Float, sharpness: Float) {
        guard let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        let ev = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        if let pattern = try? CHHapticPattern(events: [ev], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    private func playResetPattern(engine: CHHapticEngine) {
        var events: [CHHapticEvent] = []
        for i in 0..<5 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.3 + Double(i) * 0.14)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: Double(i) * 0.12
            ))
        }
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0.65,
            duration: 0.8
        ))
        if let pattern = try? CHHapticPattern(events: events, parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }
}
