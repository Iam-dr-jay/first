import Foundation
import WatchKit
import CoreHaptics

/// Drives all haptic output — both WKInterfaceDevice basic patterns and
/// CHHapticEngine custom AHAP-style sequences for max neural feel.
@MainActor
final class HapticEngine: ObservableObject {

    // MARK: - State

    @Published var isRunning = false
    @Published var currentMode: FeelProgram.HapticMode?

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var pulseTimer: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        setupEngine()
    }

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in self?.setupEngine() }
            }
            engine?.stoppedHandler = { reason in
                print("[HapticEngine] stopped: \(reason)")
            }
            try engine?.start()
        } catch {
            print("[HapticEngine] init failed: \(error)")
        }
    }

    // MARK: - Public API

    /// Start a continuous haptic program, biometric-synced to `heartRate`.
    func start(mode: FeelProgram.HapticMode, heartRate: Double) {
        stop()
        currentMode = mode
        isRunning = true

        switch mode {
        case .energyBoost:  startEnergyBoost(heartRate: heartRate)
        case .calmFlow:     startCalmFlow()
        case .focusLock:    startFocusLock(heartRate: heartRate)
        case .neuralReset:  startNeuralReset()
        }
    }

    /// Update tempo when live HR changes (called from ActiveSessionView).
    func updateHeartRate(_ hr: Double) {
        guard isRunning, let mode = currentMode else { return }
        // Restart the timer-based programs with the new HR sync.
        switch mode {
        case .energyBoost: startEnergyBoost(heartRate: hr)
        case .focusLock:   startFocusLock(heartRate: hr)
        default: break
        }
    }

    func stop() {
        pulseTimer?.cancel()
        pulseTimer = nil
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        isRunning = false
        currentMode = nil
    }

    // MARK: - Programs

    private func startEnergyBoost(heartRate: Double) {
        pulseTimer?.cancel()
        // Sync interval to live HR, bounded 90-160 bpm.
        let bpm = max(90, min(160, heartRate > 0 ? heartRate : 120))
        let interval = 60.0 / bpm

        pulseTimer = Task {
            var phase = 0
            while !Task.isCancelled {
                let intensity = 0.4 + Double(phase % 4) * 0.15  // ascending 0.4 → 0.85
                playBasicPulse(intensity: Float(min(intensity, 1.0)))
                try? await Task.sleep(for: .seconds(interval))
                phase += 1
            }
        }
    }

    private func startCalmFlow() {
        guard let engine else { fallback60bpm(); return }
        let interval = 1.0  // 60 bpm base

        pulseTimer = Task {
            var t = 0.0
            while !Task.isCancelled {
                // Sinusoidal intensity: 0.2 … 0.8
                let intensity = Float(0.2 + 0.6 * (sin(t * .pi) + 1.0) / 2.0)
                let sharpness = Float(0.3 + 0.4 * (1.0 - sin(t * .pi)))
                playCustomPulse(engine: engine, intensity: intensity, sharpness: sharpness)
                try? await Task.sleep(for: .seconds(interval))
                t += 1.0
            }
        }
    }

    private func startFocusLock(heartRate: Double) {
        pulseTimer?.cancel()
        let bpm = max(70, min(100, heartRate > 0 ? heartRate : 80))
        let interval = 60.0 / bpm

        pulseTimer = Task {
            while !Task.isCancelled {
                playBasicPulse(intensity: 0.6)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func startNeuralReset() {
        guard let engine else { fallbackReset(); return }
        // Complex AHAP-style: burst of transients + long continuous
        pulseTimer = Task {
            while !Task.isCancelled {
                playNeuralResetPattern(engine: engine)
                try? await Task.sleep(for: .seconds(3.0))
            }
        }
    }

    // MARK: - Primitives

    private func playBasicPulse(intensity: Float) {
        WKInterfaceDevice.current().play(.click)
        // Layer a custom haptic on top if engine is available.
        if let engine {
            playCustomPulse(engine: engine, intensity: intensity, sharpness: 0.7)
        }
    }

    private func playCustomPulse(engine: CHHapticEngine, intensity: Float, sharpness: Float) {
        let intensityParam  = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam  = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let p = try engine.makePlayer(with: pattern)
            try p.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticEngine] pulse error: \(error)")
        }
    }

    private func playNeuralResetPattern(engine: CHHapticEngine) {
        var events: [CHHapticEvent] = []
        // 5 ascending transients
        for i in 0..<5 {
            let t = Double(i) * 0.12
            let intensity = Float(0.3 + Double(i) * 0.14)
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: t
            ))
        }
        // Sustained low-intensity continuous rumble
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0.65,
            duration: 0.8
        ))
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let p = try engine.makePlayer(with: pattern)
            try p.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticEngine] reset pattern error: \(error)")
        }
    }

    // MARK: - Fallbacks (when CHHapticEngine unavailable)

    private func fallback60bpm() {
        pulseTimer = Task {
            while !Task.isCancelled {
                WKInterfaceDevice.current().play(.notification)
                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }

    private func fallbackReset() {
        pulseTimer = Task {
            let types: [WKHapticType] = [.click, .directionUp, .success, .retry]
            for type in types {
                WKInterfaceDevice.current().play(type)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}
