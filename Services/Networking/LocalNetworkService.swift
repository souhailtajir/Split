//
//  LocalNetworkService.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation
import Network

// MARK: - LocalNetworkError

enum LocalNetworkError: Error, LocalizedError, Sendable {
    case peerNotConnected
    case listenerFailed(Error)

    var errorDescription: String? {
        switch self {
        case .peerNotConnected:
            "The peer is not connected."
        case .listenerFailed(let error):
            "Listener failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - LocalNetworkService

/// Wraps `NWListener`, `NWBrowser`, and `NWConnection` to provide local
/// peer discovery and communication over Wi-Fi and peer-to-peer interfaces.
///
/// All mutable state is isolated to `@MainActor` to satisfy Swift 6
/// strict concurrency requirements. Network framework callbacks dispatch
/// back to the main actor via structured concurrency (`Task { @MainActor in }`).
@MainActor
final class LocalNetworkService {

    // MARK: - Constants

    static let serviceType = "_split-sync._tcp"

    // MARK: - State

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [NWEndpoint: NWConnection] = [:]

    /// Whether the listener is in the `.ready` state.
    private(set) var isAdvertising = false

    /// Whether the browser is in the `.ready` state.
    private(set) var isBrowsing = false

    /// Endpoints discovered by the browser (excluding self).
    private(set) var discoveredPeers: Set<NWEndpoint> = []

    /// Endpoints whose connections have reached the `.ready` state.
    private(set) var readyPeers: Set<NWEndpoint> = []

    /// The name this device advertises; used to filter self from browse results.
    private var advertisedName: String?

    // MARK: - Callbacks

    /// Called when a peer connection transitions to `.ready`.
    var onPeerConnected: (@MainActor (NWEndpoint) -> Void)?

    /// Called when a peer connection is cancelled or fails.
    var onPeerDisconnected: (@MainActor (NWEndpoint) -> Void)?

    /// Called when a complete length-prefixed message is received from a peer.
    var onDataReceived: (@MainActor (Data, NWEndpoint) -> Void)?

    // MARK: - Advertising

    /// Begins advertising this device on the local network as a Bonjour service.
    ///
    /// Creates an `NWListener` with TCP parameters and peer-to-peer enabled,
    /// then registers a Bonjour service with the given display name.
    ///
    /// - Parameter name: A human-readable name for this device (e.g., the user's
    ///   display name). Also used to filter self from browse results.
    func startAdvertising(as name: String) {
        guard listener == nil else { return }
        advertisedName = name

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        do {
            let newListener = try NWListener(using: parameters)
            newListener.service = NWListener.Service(
                name: name,
                type: Self.serviceType
            )

            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(state)
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleIncomingConnection(connection)
                }
            }

            newListener.start(queue: .main)
            listener = newListener
        } catch {
            isAdvertising = false
        }
    }

    /// Stops advertising this device on the local network.
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
        advertisedName = nil
    }

    // MARK: - Browsing

    /// Begins browsing for other devices advertising the same Bonjour service type.
    ///
    /// Discovered peers are stored in ``discoveredPeers``. Connections are
    /// initiated automatically to each new peer.
    func startBrowsing() {
        guard browser == nil else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let newBrowser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: parameters
        )

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleBrowserState(state)
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results)
            }
        }

        newBrowser.start(queue: .main)
        browser = newBrowser
    }

    /// Stops browsing for peers and clears discovered peer state.
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        discoveredPeers.removeAll()
    }

    // MARK: - Sending Data

    /// Sends length-prefixed data to a specific connected peer.
    ///
    /// The payload is wrapped with a 4-byte big-endian length header before
    /// transmission, matching the framing used by ``receiveNextMessage(on:from:)``.
    ///
    /// - Parameters:
    ///   - data: The raw payload to send.
    ///   - peer: The endpoint of the connected peer.
    /// - Throws: ``LocalNetworkError/peerNotConnected`` if the peer has no
    ///   ready connection.
    func send(_ data: Data, to peer: NWEndpoint) async throws {
        guard let connection = connections[peer], readyPeers.contains(peer) else {
            throw LocalNetworkError.peerNotConnected
        }

        let framedData = Self.frame(data)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: framedData,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    /// Broadcasts length-prefixed data to all currently connected peers.
    ///
    /// Sends sequentially to each ready peer. If any single send fails,
    /// the error propagates and remaining peers are skipped.
    func broadcast(_ data: Data) async throws {
        for endpoint in readyPeers {
            try await send(data, to: endpoint)
        }
    }

    // MARK: - Disconnection

    /// Disconnects from a specific peer, cancelling its connection.
    func disconnect(from peer: NWEndpoint) {
        connections[peer]?.cancel()
        connections.removeValue(forKey: peer)
        readyPeers.remove(peer)
    }

    /// Disconnects from all peers and tears down every connection.
    func disconnectAll() {
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        readyPeers.removeAll()
    }

    // MARK: - Private: Listener State

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isAdvertising = true

        case .failed:
            isAdvertising = false
            // Tear down the failed listener so a fresh one can be created
            listener?.cancel()
            listener = nil

        case .cancelled:
            isAdvertising = false

        default:
            break
        }
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        let endpoint = connection.endpoint

        // Reject duplicate connections to the same endpoint
        if connections[endpoint] != nil {
            connection.cancel()
            return
        }

        startConnection(connection, for: endpoint)
    }

    // MARK: - Private: Browser State

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            isBrowsing = true

        case .failed:
            isBrowsing = false
            browser?.cancel()
            browser = nil

        case .cancelled:
            isBrowsing = false

        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        // Build the set of discovered endpoints, filtering out our own service
        let filtered: Set<NWEndpoint> = Set(
            results.compactMap { result in
                if case .service(let name, _, _, _) = result.endpoint,
                   name == advertisedName {
                    return nil // skip self
                }
                return result.endpoint
            }
        )

        // Initiate connections to newly discovered peers
        for endpoint in filtered
        where !discoveredPeers.contains(endpoint) && connections[endpoint] == nil {
            connectToPeer(at: endpoint)
        }

        // Clean up peers that have disappeared from browse results
        for endpoint in discoveredPeers where !filtered.contains(endpoint) {
            disconnect(from: endpoint)
        }

        discoveredPeers = filtered
    }

    private func connectToPeer(at endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let connection = NWConnection(to: endpoint, using: parameters)
        startConnection(connection, for: endpoint)
    }

    // MARK: - Private: Connection Lifecycle

    /// Registers a connection for the given endpoint, installs a state handler,
    /// starts the connection, and begins the receive loop.
    private func startConnection(_ connection: NWConnection, for endpoint: NWEndpoint) {
        connections[endpoint] = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleConnectionState(state, for: endpoint)
            }
        }

        connection.start(queue: .main)
        receiveNextMessage(on: connection, from: endpoint)
    }

    private func handleConnectionState(
        _ state: NWConnection.State,
        for endpoint: NWEndpoint
    ) {
        switch state {
        case .ready:
            readyPeers.insert(endpoint)
            onPeerConnected?(endpoint)

        case .failed:
            // Cancel explicitly to ensure .cancelled fires and cleans up
            connections[endpoint]?.cancel()
            connections.removeValue(forKey: endpoint)
            readyPeers.remove(endpoint)
            onPeerDisconnected?(endpoint)

        case .cancelled:
            connections.removeValue(forKey: endpoint)
            readyPeers.remove(endpoint)
            onPeerDisconnected?(endpoint)

        default:
            break
        }
    }

    // MARK: - Private: Framing

    /// Prepends a 4-byte big-endian length header to the payload.
    private static func frame(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var framed = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        framed.append(data)
        return framed
    }

    /// Reads a length-prefixed message: first the 4-byte header, then the body.
    ///
    /// On success, delivers the body to ``onDataReceived`` and schedules
    /// the next read. On failure, disconnects the peer.
    private func receiveNextMessage(
        on connection: NWConnection,
        from endpoint: NWEndpoint
    ) {
        // Step 1: read the 4-byte length header
        connection.receive(
            minimumIncompleteLength: 4,
            maximumLength: 4
        ) { [weak self] headerData, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                guard let headerData, headerData.count == 4 else {
                    if error != nil { self.disconnect(from: endpoint) }
                    return
                }

                let length = headerData.withUnsafeBytes {
                    $0.load(as: UInt32.self).bigEndian
                }

                // Reject zero-length or absurdly large frames (> 10 MB)
                guard length > 0, length < 10_000_000 else {
                    self.disconnect(from: endpoint)
                    return
                }

                self.receiveBody(
                    of: Int(length),
                    on: connection,
                    from: endpoint
                )
            }
        }
    }

    /// Step 2 of the receive loop: reads the message body after the header.
    private func receiveBody(
        of length: Int,
        on connection: NWConnection,
        from endpoint: NWEndpoint
    ) {
        connection.receive(
            minimumIncompleteLength: length,
            maximumLength: length
        ) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let data {
                    self.onDataReceived?(data, endpoint)
                }

                if error != nil {
                    self.disconnect(from: endpoint)
                    return
                }

                // Continue the receive loop for the next message
                self.receiveNextMessage(on: connection, from: endpoint)
            }
        }
    }
}
