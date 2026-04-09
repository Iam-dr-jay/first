import Foundation
import SwiftUI

enum NeuralState: String, CaseIterable {
    case active   = "Active"
    case stressed = "Stressed"
    case calm     = "Calm"
    case focused  = "Focused"
    case unknown  = "Reading..."

    var color: Color {
        switch self {
        case .active:   return .orange
        case .stressed: return .red
        case .calm:     return .green
        case .focused:  return .blue
        case .unknown:  return .gray
        }
    }

    var icon: String {
        switch self {
        case .active:   return "flame.fill"
        case .stressed: return "exclamationmark.triangle.fill"
        case .calm:     return "leaf.fill"
        case .focused:  return "target"
        case .unknown:  return "waveform.path.ecg"
        }
    }

    var description: String {
        switch self {
        case .active:   return "High arousal · elevated motion"
        case .stressed: return "Elevated HR · low HRV"
        case .calm:     return "Low HR · high HRV"
        case .focused:  return "Moderate HR · low motion"
        case .unknown:  return "Collecting biometrics..."
        }
    }

    static func infer(heartRate: Double, hrv: Double, motionMagnitude: Double) -> NeuralState {
        guard heartRate > 0 else { return .unknown }
        if heartRate > 90 && motionMagnitude > 1.2       { return .active }
        if heartRate > 80 && hrv < 30                    { return .stressed }
        if heartRate < 70 && hrv > 50                    { return .calm }
        if (60...85).contains(heartRate) && motionMagnitude < 0.4 { return .focused }
        return .unknown
    }
}
