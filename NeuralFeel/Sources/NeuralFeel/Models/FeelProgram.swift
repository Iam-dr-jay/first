import Foundation
import SwiftUI

struct FeelProgram: Identifiable, Hashable {
    let id: UUID
    let name: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let hapticMode: HapticMode
    let targetHR: ClosedRange<Double>
    let description: String

    enum HapticMode: String, CaseIterable {
        case energyBoost = "Energy Boost"
        case calmFlow    = "Calm Flow"
        case focusLock   = "Focus Lock"
        case neuralReset = "Neural Reset"

        var bpm: Double {
            switch self {
            case .energyBoost: return 120
            case .calmFlow:    return 60
            case .focusLock:   return 80
            case .neuralReset: return 100
            }
        }

        var intervalSeconds: Double { 60.0 / bpm }

        /// Left motor (heavy rumble) intensity for DS4
        var ds4LeftIntensity: Float {
            switch self {
            case .energyBoost: return 0.85
            case .calmFlow:    return 0.20
            case .focusLock:   return 0.45
            case .neuralReset: return 0.70
            }
        }

        /// Right motor (light rumble) intensity for DS4
        var ds4RightIntensity: Float {
            switch self {
            case .energyBoost: return 0.60
            case .calmFlow:    return 0.35
            case .focusLock:   return 0.55
            case .neuralReset: return 0.80
            }
        }
    }

    static let all: [FeelProgram] = [
        FeelProgram(
            id: UUID(),
            name: "Energy Boost",
            subtitle: "Ascending neural drive",
            icon: "bolt.fill",
            accentColor: .orange,
            hapticMode: .energyBoost,
            targetHR: 100...140,
            description: "Escalating Taptic + DS4 heavy rumble bursts at 120 bpm. Activates sympathetic arousal."
        ),
        FeelProgram(
            id: UUID(),
            name: "Calm Flow",
            subtitle: "Parasympathetic wave",
            icon: "water.waves",
            accentColor: .cyan,
            hapticMode: .calmFlow,
            targetHR: 50...75,
            description: "Slow sinusoidal haptic waves at 60 bpm across phone + controller. Entrains HRV."
        ),
        FeelProgram(
            id: UUID(),
            name: "Focus Lock",
            subtitle: "Steady neural metronome",
            icon: "scope",
            accentColor: .indigo,
            hapticMode: .focusLock,
            targetHR: 65...90,
            description: "Precision metronome on iPhone Taptic + DS4 right motor at 80 bpm."
        ),
        FeelProgram(
            id: UUID(),
            name: "Neural Reset",
            subtitle: "Full system reboot",
            icon: "arrow.trianglehead.2.clockwise.rotate.90",
            accentColor: .purple,
            hapticMode: .neuralReset,
            targetHR: 60...100,
            description: "Complex AHAP transient + continuous pattern. Both DS4 motors + iPhone Taptic in sync."
        )
    ]
}
