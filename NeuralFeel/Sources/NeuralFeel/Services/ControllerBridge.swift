import Foundation
import GameController
import CoreHaptics

/// Manages DualShock 4 connection and drives both rumble motors
/// (left = heavy bass, right = light treble) via Core Haptics.
/// The DS4 is detected whether connected to iPhone via Bluetooth
/// or to Surface Pro — in Surface mode it appears as a web gamepad and
/// only the iPhone path drives haptics.
@MainActor
final class ControllerBridge: ObservableObject {

    @Published var isConnected = false
    @Published var controllerName: String = "No controller"
    @Published var leftMotorLevel: Float = 0
    @Published var rightMotorLevel: Float = 0

    private var controller: GCController?
    private var leftEngine: CHHapticEngine?
    private var rightEngine: CHHapticEngine?
    private var motorTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        GCController.startWirelessControllerDiscovery()
        // Grab any already-connected controller
        if let existing = GCController.controllers().first {
            attach(existing)
        }
    }

    func stopMonitoring() {
        GCController.stopWirelessControllerDiscovery()
        NotificationCenter.default.removeObserver(self)
        stopHaptics()
    }

    // MARK: - Program playback

    func play(mode: FeelProgram.HapticMode, heartRate: Double) {
        stopHaptics()
        leftMotorLevel  = mode.ds4LeftIntensity
        rightMotorLevel = mode.ds4RightIntensity

        switch mode {
        case .energyBoost: runPulse(left: mode.ds4LeftIntensity, right: mode.ds4RightIntensity, hr: heartRate)
        case .calmFlow:    runSine()
        case .focusLock:   runMetronome(left: mode.ds4LeftIntensity, right: mode.ds4RightIntensity, hr: heartRate)
        case .neuralReset: runReset()
        }
    }

    func stopHaptics() {
        motorTask?.cancel()
        motorTask = nil
        leftMotorLevel  = 0
        rightMotorLevel = 0
        // Silence both motors
        fireMotors(left: 0, right: 0, duration: 0.01)
    }

    func syncHeartRate(_ hr: Double) {
        guard let mode = (controller != nil ? leftMotorLevel > 0 : false) ? FeelProgram.HapticMode.energyBoost : nil else { return }
        _ = mode
        // Re-sync tempo-based programs; caller should call play(mode:heartRate:) directly
    }

    // MARK: - Motor programs

    private func runPulse(left: Float, right: Float, hr: Double) {
        motorTask = Task {
            let bpm = max(90, min(160, hr > 0 ? hr : 120))
            let interval = 60.0 / bpm
            var phase = 0
            while !Task.isCancelled {
                let scale = Float(min(0.5 + Double(phase % 4) * 0.125, 1.0))
                fireMotors(left: left * scale, right: right * scale, duration: Float(interval * 0.4))
                try? await Task.sleep(for: .seconds(interval))
                phase += 1
            }
        }
    }

    private func runSine() {
        motorTask = Task {
            var t = 0.0
            while !Task.isCancelled {
                let wave = Float((sin(t * .pi) + 1) / 2)
                fireMotors(left: 0.15 + 0.25 * wave, right: 0.25 + 0.20 * wave, duration: 0.8)
                try? await Task.sleep(for: .seconds(1.0))
                t += 1
            }
        }
    }

    private func runMetronome(left: Float, right: Float, hr: Double) {
        motorTask = Task {
            let bpm = max(70, min(100, hr > 0 ? hr : 80))
            let interval = 60.0 / bpm
            while !Task.isCancelled {
                fireMotors(left: left, right: right, duration: Float(interval * 0.3))
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func runReset() {
        motorTask = Task {
            while !Task.isCancelled {
                // Ascending left bursts
                for i in 0..<5 {
                    let intensity = Float(0.2 + Double(i) * 0.16)
                    fireMotors(left: intensity, right: 0.9 - intensity * 0.5, duration: 0.08)
                    try? await Task.sleep(for: .milliseconds(120))
                }
                // Long low-frequency sustain
                fireMotors(left: 0.25, right: 0.1, duration: 0.8)
                try? await Task.sleep(for: .seconds(3.0))
            }
        }
    }

    // MARK: - Low-level motor fire

    private func fireMotors(left: Float, right: Float, duration: Float) {
        guard let profile = controller?.physicalInputProfile as? GCDualShock4Gamepad else { return }
        _ = profile  // GCDualShock4Gamepad doesn't expose motors directly; use CHHapticEngine

        // Drive via haptics locality if available (iOS 14+)
        guard let haptics = controller?.haptics else { return }

        for locality in [GCHapticsLocality.leftHandle, GCHapticsLocality.rightHandle] {
            guard haptics.supportedLocalities.contains(locality) else { continue }
            guard let eng = try? CHHapticEngine(haptics: haptics, locality: locality) else { continue }
            let intensity: Float = locality == .leftHandle ? left : right
            guard intensity > 0 else { continue }
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: TimeInterval(duration)
            )
            if let pattern = try? CHHapticPattern(events: [event], parameters: []),
               let player  = try? eng.makePlayer(with: pattern) {
                try? eng.start()
                try? player.start(atTime: CHHapticTimeImmediate)
            }
        }
    }

    // MARK: - Notifications

    @objc private func controllerConnected(_ note: Notification) {
        if let ctrl = note.object as? GCController { attach(ctrl) }
    }

    @objc private func controllerDisconnected(_ note: Notification) {
        controller = nil
        isConnected = false
        controllerName = "Disconnected"
        leftMotorLevel  = 0
        rightMotorLevel = 0
    }

    private func attach(_ ctrl: GCController) {
        controller    = ctrl
        isConnected   = true
        controllerName = ctrl.vendorName ?? "DualShock 4"
    }
}
