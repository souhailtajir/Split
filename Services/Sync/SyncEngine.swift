//
//  SyncEngine.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation
import Network

/// Manages local peer-to-peer sync state by coordinating a ``LocalNetworkService``.
///
/// Exposes reactive, observable state for SwiftUI consumption. All state is
/// `@MainActor`-isolated to satisfy Swift 6 strict concurrency requirements.
///
/// ## Usage
/// ```swift
/// @State private var engine = SyncEngine()
///
/// var body: some View {
///     Text(engine.connectionState.label)
///         .onAppear { engine.start(displayName: "My iPhone") }
///         .onDisappear { engine.stop() }
/// }
/// ```
@Observable
@MainActor
final class SyncEngine {

    // MARK: - Connection State

    /// A composite representation of the engine's networking phase.
    enum ConnectionState: Sendable, Equatable {
        /// Not advertising or browsing.
        case idle
        /// Listener is active but no peers discovered yet.
        case advertising
        /// Both advertising and browsing; searching for peers.
        case browsing
        /// Connected to one or more peers.
        case connected(peerCount: Int)
        /// An error occurred (informational; the engine may still be partially active).
        case error(String)

        /// A human-readable label suitable for display in the UI.
        var label: String {
            switch self {
            case .idle:
                "Idle"
            case .advertising:
                "Advertising…"
            case .browsing:
                "Searching for peers…"
            case .connected(let count):
                "\(count) peer\(count == 1 ? "" : "s") connected"
            case .error(let message):
                "Error: \(message)"
            }
        }
    }

    // MARK: - Observable State

    /// Whether the underlying listener is advertising on the local network.
    private(set) var isAdvertising = false

    /// Whether the underlying browser is actively scanning for peers.
    private(set) var isBrowsing = false

    /// The number of peers whose connections are in the `.ready` state.
    private(set) var connectedPeerCount = 0

    /// The number of peers visible via Bonjour (may not yet be connected).
    private(set) var discoveredPeerCount = 0

    /// A composite state derived from advertising, browsing, and peer counts.
    private(set) var connectionState: ConnectionState = .idle

    // MARK: - Private

    /// The underlying networking layer.
    private let networkService = LocalNetworkService()

    /// Stable device identity persisted across launches.
    /// Feeds into ``LocalMutationTrackable/lastModifiedByDeviceID``.
    let deviceID: String

    // MARK: - Init

    init() {
        deviceID = Self.resolveDeviceID()
        bindNetworkCallbacks()
    }

    // MARK: - Public API

    /// Starts advertising this device and browsing for peers on the local network.
    ///
    /// - Parameter displayName: The name shown to other peers during Bonjour discovery.
    func start(displayName: String) {
        networkService.startAdvertising(as: displayName)
        networkService.startBrowsing()
        refreshState()
    }

    /// Stops all networking: advertising, browsing, and disconnects every peer.
    func stop() {
        networkService.stopAdvertising()
        networkService.stopBrowsing()
        networkService.disconnectAll()
        refreshState()
    }

    // MARK: - Private: Callbacks

    private func bindNetworkCallbacks() {
        networkService.onPeerConnected = { [weak self] _ in
            self?.refreshState()
        }

        networkService.onPeerDisconnected = { [weak self] _ in
            self?.refreshState()
        }

        networkService.onDataReceived = { [weak self] data, endpoint in
            self?.handleDataReceived(data, from: endpoint)
        }
    }

    /// Processes an incoming sync payload from a peer.
    ///
    /// - Note: This is a placeholder for future sync logic. Once implemented,
    ///   it will decode payloads and merge changes via ``LocalMutationTrackable``.
    private func handleDataReceived(_ data: Data, from endpoint: NWEndpoint) {
        // Future: decode sync payloads and merge via LocalMutationTrackable
    }

    // MARK: - Private: State Derivation

    /// Pulls the latest values from `networkService` and recomputes derived state.
    private func refreshState() {
        isAdvertising = networkService.isAdvertising
        isBrowsing = networkService.isBrowsing
        discoveredPeerCount = networkService.discoveredPeers.count
        connectedPeerCount = networkService.readyPeers.count

        connectionState = deriveConnectionState()
    }

    private func deriveConnectionState() -> ConnectionState {
        if connectedPeerCount > 0 {
            return .connected(peerCount: connectedPeerCount)
        }
        if isBrowsing {
            return .browsing
        }
        if isAdvertising {
            return .advertising
        }
        return .idle
    }

    // MARK: - Device Identity

    private static let deviceIDKey = "com.split.deviceID"

    /// Returns a stable device identifier, creating and persisting one on first launch.
    private static func resolveDeviceID() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existing
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }
}
