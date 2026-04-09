import Foundation
import SwiftUI

/// A programmable feel state combining haptic patterns, biometric targets, and UI theme.
struct FeelProgram: Identifiable, Hashable {
    let id: UUID
    let name: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let hapticMode: HapticMode
    let targetHR: ClosedRange<Double>   // beats per minute
    let description: String

    enum HapticMode: String, CaseIterable {
        case energyBoost  = "Energy Boost"
        case calmFlow     = "Calm Flow"
        case focusLock    = "Focus Lock"
        case neuralReset  = "Neural Reset"

        var bpm: Double {
            switch self {
            case .energyBoost: return 120
            case .calmFlow:    return 60
            case .focusLock:   return 80
            case .neuralReset: return 100
            }
        }

        var intervalSeconds: Double { 60.0 / bpm }
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
            description: "Escalating haptic bursts at 120 bpm. Activates sympathetic arousal and drive."
        ),
        FeelProgram(
            id: UUID(),
            name: "Calm Flow",
            subtitle: "Parasympathetic wave",
            icon: "water.waves",
            accentColor: .cyan,
            hapticMode: .calmFlow,
            targetHR: 50...75,
            description: "Slow sinusoidal haptic waves at 60 bpm. Entrains HRV and deep calm."
        ),
        FeelProgram(
            id: UUID(),
            name: "Focus Lock",
            subtitle: "Steady neural metronome",
            icon: "scope",
            accentColor: .indigo,
            hapticMode: .focusLock,
            targetHR: 65...90,
            description: "Precision metronome pulses at 80 bpm. Anchors attention and working memory."
        ),
        FeelProgram(
            id: UUID(),
            name: "Neural Reset",
            subtitle: "Full system reboot",
            icon: "arrow.trianglehead.2.clockwise.rotate.90",
            accentColor: .purple,
            hapticMode: .neuralReset,
            targetHR: 60...100,
            description: "Complex transient + continuous AHAP pattern. Clears accumulated stress state."
        )
    ]
}
