import Foundation
import MultipeerConnectivity

/// Multipeer Connectivity bridge between iPhone 13 Pro Max (Primary)
/// and iPhone 8 Plus (Companion). Primary advertises and browsers;
/// Companion advertises and accepts sessions.
@MainActor
final class MultipeerBridge: NSObject, ObservableObject {

    enum DeviceRole { case primary, companion }

    @Published var connectedPeers: [String] = []
    @Published var lastReceivedCommand: [String: Any] = [:]
    @Published var isConnected: Bool { connectedPeers.isEmpty == false }

    private let serviceType = "neuralfeel"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var role: DeviceRole = .companion

    var onCommand: (([String: Any]) -> Void)?

    // MARK: - Start

    func start(as role: DeviceRole, displayName: String) {
        self.role = role
        myPeerID = MCPeerID(displayName: displayName)
        session  = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["role": role == .primary ? "primary" : "companion"], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        if role == .primary {
            browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
            browser?.delegate = self
            browser?.startBrowsingForPeers()
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }

    // MARK: - Send (Primary → Companions)

    func send(command: [String: Any]) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: command) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    /// Broadcast live telemetry (lossy OK)
    func broadcast(telemetry: [String: Any]) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: telemetry) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerBridge: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers.map(\.displayName)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer: MCPeerID) {
        guard let cmd = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        Task { @MainActor in
            self.lastReceivedCommand = cmd
            self.onCommand?(cmd)
        }
    }

    nonisolated func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    nonisolated func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    nonisolated func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerBridge: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peer: MCPeerID,
        withContext _: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }

    nonisolated func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[Multipeer] advertise error: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerBridge: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peer: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        // Primary invites companions automatically
        guard info?["role"] == "companion" else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    nonisolated func browser(_: MCNearbyServiceBrowser, lostPeer _: MCPeerID) {}
    nonisolated func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[Multipeer] browse error: \(error)")
    }
}
