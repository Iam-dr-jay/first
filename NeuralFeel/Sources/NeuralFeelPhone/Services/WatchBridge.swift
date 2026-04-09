import Foundation
import WatchConnectivity
import Combine

/// Bidirectional bridge between the iPhone console and the Watch app
/// via WatchConnectivity. Sends program commands and receives live telemetry.
@MainActor
final class WatchBridge: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchBridge()

    // MARK: - Published state (received from Watch)

    @Published var liveHeartRate: Double = 0
    @Published var liveHRV: Double = 0
    @Published var liveSpO2: Double = 0
    @Published var liveNeuralState: String = "Unknown"
    @Published var activeProgram: String = "None"
    @Published var sessionReachable: Bool = false

    // MARK: - Init

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Commands → Watch

    /// Launch a feel program on the Watch.
    func launchProgram(_ programName: String) {
        sendMessage(["command": "launch", "program": programName])
    }

    /// Stop any running session on the Watch.
    func stopSession() {
        sendMessage(["command": "stop"])
    }

    /// Send a custom haptic intensity override (0.0–1.0).
    func setIntensity(_ value: Double) {
        sendMessage(["command": "intensity", "value": value])
    }

    /// Request a one-time Neural Reset burst.
    func triggerNeuralReset() {
        sendMessage(["command": "neuralReset"])
    }

    // MARK: - Private send

    private func sendMessage(_ payload: [String: Any]) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { err in
            print("[WatchBridge] send error: \(err)")
        })
    }

    // MARK: - WCSessionDelegate — receive telemetry from Watch

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            sessionReachable = activationState == .activated
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            sessionReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let hr    = message["heartRate"]    as? Double { liveHeartRate  = hr }
            if let hrv   = message["hrv"]          as? Double { liveHRV        = hrv }
            if let spo2  = message["spo2"]         as? Double { liveSpO2       = spo2 }
            if let state = message["neuralState"]  as? String { liveNeuralState = state }
            if let prog  = message["activeProgram"] as? String { activeProgram  = prog }
        }
    }

    // Required on iOS (not needed on watchOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
