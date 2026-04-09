import Foundation
import CoreMotion
import Combine

/// Fuses accelerometer + gyroscope motion data with biometrics to infer
/// the user's current neural state in real time.
@MainActor
final class NeuralStateDetector: ObservableObject {

    @Published var currentState: NeuralState = .unknown
    @Published var motionMagnitude: Double = 0
    @Published var confidence: Double = 0

    private let motionManager = CMMotionManager()
    private var updateTask: Task<Void, Never>?

    // MARK: - Control

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates()
        scheduleInference()
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        updateTask?.cancel()
        updateTask = nil
    }

    // MARK: - Inference loop

    private func scheduleInference() {
        updateTask = Task {
            while !Task.isCancelled {
                if let motion = motionManager.deviceMotion {
                    let acc = motion.userAcceleration
                    let mag = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
                    self.motionMagnitude = mag
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// Called by the view layer whenever HR/HRV readings update.
    func update(heartRate: Double, hrv: Double) {
        let state = NeuralState.infer(
            heartRate: heartRate,
            hrv: hrv,
            motionMagnitude: motionMagnitude
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            currentState = state
        }
        // Confidence: higher when HR is well-established and HRV is non-zero.
        confidence = heartRate > 0 && hrv > 0 ? 1.0 : (heartRate > 0 ? 0.6 : 0.2)
    }
}
