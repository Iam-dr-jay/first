import Foundation
import CoreMotion

/// Fuses CoreMotion accelerometer + camera HR + HRV to infer neural state.
@MainActor
final class NeuralStateDetector: ObservableObject {

    @Published var currentState: NeuralState = .unknown
    @Published var motionMagnitude: Double = 0
    @Published var confidence: Double = 0

    private let motionManager = CMMotionManager()
    private var task: Task<Void, Never>?

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.25
        motionManager.startDeviceMotionUpdates()
        task = Task {
            while !Task.isCancelled {
                if let m = motionManager.deviceMotion {
                    let a = m.userAcceleration
                    motionMagnitude = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        task?.cancel()
        task = nil
    }

    func update(heartRate: Double, hrv: Double) {
        let next = NeuralState.infer(heartRate: heartRate, hrv: hrv, motionMagnitude: motionMagnitude)
        withAnimation(.easeInOut(duration: 0.6)) { currentState = next }
        confidence = heartRate > 0 ? (hrv > 0 ? 1.0 : 0.6) : 0.2
    }
}
