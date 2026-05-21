import Flutter
import UIKit
import MultipeerConnectivity

@objc class MeshPlugin: NSObject, FlutterPlugin {
    private static let kMethod = "bushtrack/mesh"
    private static let kEvents = "bushtrack/mesh/events"

    private var eventSink: FlutterEventSink?
    private var myPeerId: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Registration

    @objc static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MeshPlugin()
        let method = FlutterMethodChannel(name: kMethod, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: method)
        let events = FlutterEventChannel(name: kEvents, binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
    }

    // MARK: - Method channel

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let userName = args["userName"] as? String else {
                result(FlutterError(code: "ARGS", message: "userName required", details: nil))
                return
            }
            startMesh(userName: userName)
            result(nil)

        case "stop":
            stopMesh()
            result(nil)

        case "sendBytes":
            guard let args = call.arguments as? [String: Any],
                  let peerId = args["peerId"] as? String,
                  let typed = args["bytes"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "ARGS", message: "peerId and bytes required", details: nil))
                return
            }
            sendData(typed.data, toPeer: peerId)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Mesh lifecycle

    private func startMesh(userName: String) {
        myPeerId = MCPeerID(displayName: userName)
        guard let me = myPeerId else { return }

        session = MCSession(peer: me, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: nil, serviceType: "bushtrack")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: me, serviceType: "bushtrack")
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    private func stopMesh() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
    }

    private func sendData(_ data: Data, toPeer peerId: String) {
        guard let session = session else { return }
        let targets = session.connectedPeers.filter { $0.displayName == peerId }
        guard !targets.isEmpty else { return }
        try? session.send(data, toPeers: targets, with: .reliable)
    }

    private func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { self.eventSink?(event) }
    }
}

// MARK: - MCSessionDelegate

extension MeshPlugin: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            emit(["type": "peerConnected", "peerId": peerID.displayName])
        case .notConnected:
            emit(["type": "peerDisconnected", "peerId": peerID.displayName])
        default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        emit([
            "type": "bytesReceived",
            "peerId": peerID.displayName,
            "bytes": FlutterStandardTypedData(bytes: data),
        ])
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName name: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName name: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MeshPlugin: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MeshPlugin: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        guard let session = session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

// MARK: - FlutterStreamHandler

extension MeshPlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
