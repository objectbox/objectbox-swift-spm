//
// Copyright (c) 2026 ObjectBox. https://objectbox.io
//

import Foundation
import NearbyConnections
import ObjectBox

/// Hands a single non-Sendable value across a concurrency boundary to exactly one consumer.
final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

/// Experimental: mesh sync transport based on Google Nearby Connections for Apple platforms.
/// The analog of the Android `NearbyMeshNetwork` and wire-compatible with it (same Nearby strategy, same hex
/// encoding of the endpoint metadata), so Apple and Android devices can join the same mesh
/// (interop still to be verified on real devices, see the mesh docs).
///
/// Create instances via ``AppleMeshSync/createConfig(meshId:)`` rather than directly; optional settings like
/// ``mediums`` are then reachable via the returned config (e.g. `MeshConfig/nearbyMediums`).
///
/// The Nearby objects are created when the core starts this transport (using the mesh ID as the Nearby service
/// ID), not on construction: creating a `ConnectionManager` already initializes Nearby's medium stacks
/// (e.g. Bluetooth, which may prompt on macOS), so this keeps an unused configuration radio-silent.
///
/// Threading: outbound calls arrive on the ObjectBox mesh sync thread and are handed to the non-blocking
/// Nearby API; Nearby delegate callbacks arrive on a dedicated serial queue and are fed back to the core
/// via the ``MeshNetwork`` bridge (whose event methods are thread-safe).
public final class NearbyMeshNetwork {

    /// Max size of a single Nearby `BYTES` payload; mirrors Android's
    /// `ConnectionsClient.MAX_BYTES_DATA_SIZE` (1023 KB). Larger messages are sent as a `STREAM` payload.
    public static let messageSizeLimit = 1023 * 1024

    /// Upper bound for a single large message sent via a `STREAM` payload. Set rather high (TX logs are
    /// typically much smaller), but not unbounded, as the stream is reassembled in memory.
    public static let extendedMessageSizeLimit = 256 * 1024 * 1024

    /// The Nearby objects for one mesh; created by `start(meshId:)`.
    private final class Nearby {
        let connectionManager: ConnectionManager
        let advertiser: Advertiser
        let discoverer: Discoverer

        init(serviceId: String, queue: DispatchQueue) {
            // Nearby requires advertiser and discoverer to use the same strategy: P2P_CLUSTER (M-to-N) like the
            // Android transport; .pointToPoint would limit a node to a single connection. The mesh topology is
            // built on top by maintaining multiple 1:1 connections.
            connectionManager = ConnectionManager(serviceID: serviceId, strategy: .cluster, queue: queue)
            advertiser = Advertiser(connectionManager: connectionManager)
            discoverer = Discoverer(connectionManager: connectionManager)
        }
    }

    /// Optionally restricts the Nearby mediums used for advertising and discovery; nil (the default) does not
    /// restrict them, Nearby then uses all mediums it supports. E.g. `[.wifiLAN]` avoids Bluetooth entirely
    /// (including its permission prompt) when all nodes are on the same network - also used by the smoke test.
    /// Set it before the sync client (and thus this transport) starts; later changes are ignored.
    /// Note: Nearby always uses all mediums for outgoing connection requests, the restriction applies to
    /// advertising and discovery only. Thread-safe.
    public var mediums: Set<Medium>? {
        get { withLock { mediumsValue } }
        set { withLock { if !started { mediumsValue = newValue } } }
    }
    private var mediumsValue: Set<Medium>?
    /// Set once ``start(meshId:)`` ran; from then on ``mediums`` is frozen (guarded by `lock`)
    private var started = false

    private let delegateQueue = DispatchQueue(label: "io.objectbox.mesh.nearby")

    /// Set once by `start(meshId:)`, the guaranteed first outbound call; only touched by the outbound calls,
    /// which arrive sequentially on the mesh sync thread (the delegate callbacks get their objects as parameters).
    private var nearby: Nearby?

    private let lock = NSLock()
    /// Weak, as required by `MeshNetworkTransport`: the core retains this transport, not the other way around.
    private weak var weakBridge: MeshNetwork?
    /// Advertising info seen in discovery, by endpoint; used for the outgoing-side connection check
    /// (on Apple, the initiator does not receive the advertiser's context again at connection time).
    private var discoveredEndpointInfo = [EndpointID: Data]()
    /// Endpoints we requested a connection to (outgoing); incoming requests are checked in the
    /// advertiser delegate instead.
    private var outgoingRequests = Set<EndpointID>()
    private var connectedEndpoints = Set<EndpointID>()
    /// Incoming STREAM payloads being reassembled, and those Nearby reported as failed/canceled meanwhile
    private var incomingStreams = Set<PayloadID>()
    private var abortedIncomingStreams = Set<PayloadID>()
    private var advertising = false
    private var discovering = false

    /// The bridge to the ObjectBox mesh sync core; set by ``AppleMeshSync/createConfig(meshId:)`` and
    /// severed (set to nil) when the core stops this transport. Thread-safe: read from Nearby's callbacks.
    public internal(set) var bridge: MeshNetwork? {
        get { withLock { weakBridge } }
        set { withLock { weakBridge = newValue } }
    }

    /// Whether Nearby confirmed that advertising is active (diagnostics; e.g. used by the smoke test).
    public var isAdvertising: Bool { withLock { advertising } }

    /// Whether Nearby confirmed that discovery is active (diagnostics; e.g. used by the smoke test).
    public var isDiscovering: Bool { withLock { discovering } }

    /// Creates a transport; it advertises and discovers under the mesh ID it is started with as service ID.
    /// Optional settings (``mediums``) are properties, to be set before the transport starts.
    public init() {}

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

// MARK: - MeshNetworkTransport (outbound calls from the mesh sync core)

extension NearbyMeshNetwork: MeshNetworkTransport {

    public func start(meshId: String) {
        withLock { started = true }  // Freezes `mediums`
        let nearby = Nearby(serviceId: meshId, queue: delegateQueue)
        nearby.connectionManager.delegate = self
        nearby.advertiser.delegate = self
        nearby.discoverer.delegate = self
        self.nearby = nearby
    }

    public func startAdvertising(endpointInfo: Data) -> Bool {
        guard let nearby = nearby else { return false }
        let completion: (Error?) -> Void = { [weak self] error in
            guard let self = self else { return }
            self.withLock { self.advertising = (error == nil) }
            self.bridge?.advertisingResult(success: error == nil, errorMessage: error?.localizedDescription)
        }
        let endpointName = Self.encodeEndpointInfo(endpointInfo)  // Hex, like Android (see the coding helpers)
        if let mediums = mediums {
            nearby.advertiser.startAdvertising(using: endpointName, mediums: mediums, completionHandler: completion)
        } else {
            nearby.advertiser.startAdvertising(using: endpointName, completionHandler: completion)
        }
        return true
    }

    public func stopAdvertising() {
        withLock { advertising = false }
        nearby?.advertiser.stopAdvertising()
    }

    public func startDiscovery() -> Bool {
        guard let nearby = nearby else { return false }
        let completion: (Error?) -> Void = { [weak self] error in
            guard let self = self else { return }
            self.withLock { self.discovering = (error == nil) }
            self.bridge?.discoveryStarted(success: error == nil)
        }
        if let mediums = mediums {
            nearby.discoverer.startDiscovery(mediums: mediums, completionHandler: completion)
        } else {
            nearby.discoverer.startDiscovery(completionHandler: completion)
        }
        return true
    }

    public func stopDiscovery() {
        withLock { discovering = false }
        nearby?.discoverer.stopDiscovery()
    }

    public func connect(endpointId: String, endpointInfo: Data) -> Bool {
        guard let nearby = nearby else { return false }
        withLock { _ = outgoingRequests.insert(endpointId) }
        let endpointName = Self.encodeEndpointInfo(endpointInfo)  // Hex, like Android (see the coding helpers)
        nearby.discoverer.requestConnection(to: endpointId, using: endpointName) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.withLock { _ = self.outgoingRequests.remove(endpointId) }
            self.bridge?.connectionRequested(
                endpointId: endpointId, success: false,
                errorMessage: error.localizedDescription)
        }
        return true
    }

    public func disconnect(endpointId: String) {
        nearby?.connectionManager.disconnect(from: endpointId)
    }

    public func send(endpointId: String, data: Data) -> Bool {
        guard let nearby = nearby else { return false }
        if data.count <= Self.messageSizeLimit {
            _ = nearby.connectionManager.send(data, to: [endpointId]) { [weak self] error in
                self?.bridge?.payloadSent(endpointId: endpointId, success: error == nil)
            }
        } else {
            // A single message over the BYTES cap goes out as a STREAM payload (the large-TX-log path)
            _ = nearby.connectionManager.startStream(InputStream(data: data), to: [endpointId]) { [weak self] error in
                self?.bridge?.payloadSent(endpointId: endpointId, success: error == nil)
            }
        }
        return true
    }

    public func stop() {
        let endpoints = withLock { () -> Set<EndpointID> in
            advertising = false
            discovering = false
            let connected = connectedEndpoints
            connectedEndpoints.removeAll()
            outgoingRequests.removeAll()
            discoveredEndpointInfo.removeAll()
            incomingStreams.removeAll()
            abortedIncomingStreams.removeAll()
            return connected
        }
        if let nearby = nearby {
            nearby.advertiser.stopAdvertising()
            nearby.discoverer.stopDiscovery()
            for endpointId in endpoints {
                nearby.connectionManager.disconnect(from: endpointId)
            }
            // Detach from Nearby's callbacks; the Nearby objects themselves go away with this transport
            nearby.connectionManager.delegate = nil
            nearby.advertiser.delegate = nil
            nearby.discoverer.delegate = nil
        }
        bridge = nil  // Sever the bidirectional references (mirrors the Android transport's stop())
    }
}

// MARK: - Nearby delegates (inbound events; on delegateQueue)

extension NearbyMeshNetwork: DiscovererDelegate {

    public func discoverer(_ discoverer: Discoverer, didFind endpointID: EndpointID, with context: Data) {
        let endpointInfo = Self.decodeEndpointInfo(context)  // Peers advertise hex-encoded metadata
        withLock { discoveredEndpointInfo[endpointID] = endpointInfo }
        bridge?.endpointFound(endpointId: endpointID, endpointInfo: endpointInfo)
    }

    public func discoverer(_ discoverer: Discoverer, didLose endpointID: EndpointID) {
        withLock { _ = discoveredEndpointInfo.removeValue(forKey: endpointID) }
        bridge?.endpointLost(endpointId: endpointID)
    }
}

extension NearbyMeshNetwork: AdvertiserDelegate {

    public func advertiser(
        _ advertiser: Advertiser, didReceiveConnectionRequestFrom endpointID: EndpointID,
        with context: Data, connectionRequestHandler: @escaping (Bool) -> Void
    ) {
        // Incoming connection: the context is the initiator's hex-encoded connection info ("ObxCon")
        let endpointInfo = Self.decodeEndpointInfo(context)
        let accept =
            bridge?.checkConnectionRequest(
                endpointId: endpointID, endpointInfo: endpointInfo,
                incoming: true) ?? false
        connectionRequestHandler(accept)
    }
}

extension NearbyMeshNetwork: ConnectionManagerDelegate {

    public func connectionManager(
        _ connectionManager: ConnectionManager, didReceive verificationCode: String,
        from endpointID: EndpointID,
        verificationHandler: @escaping (Bool) -> Void
    ) {
        // Nearby encrypts connections and offers the code for out-of-band verification; like the Android
        // transport we auto-accept it. On the outgoing side, this is where the core validates the
        // advertiser's info (which we remembered from discovery); the incoming side was already checked
        // in the advertiser delegate.
        let isOutgoing = withLock { outgoingRequests.contains(endpointID) }
        if isOutgoing {
            let advertisingInfo = withLock { discoveredEndpointInfo[endpointID] } ?? Data()
            let accept =
                bridge?.checkConnectionRequest(
                    endpointId: endpointID, endpointInfo: advertisingInfo,
                    incoming: false) ?? false
            verificationHandler(accept)
        } else {
            verificationHandler(true)
        }
    }

    public func connectionManager(
        _ connectionManager: ConnectionManager, didReceive data: Data,
        withID payloadID: PayloadID, from endpointID: EndpointID
    ) {
        bridge?.messageReceived(endpointId: endpointID, data: data)
    }

    public func connectionManager(
        _ connectionManager: ConnectionManager, didReceive stream: InputStream,
        withID payloadID: PayloadID, from endpointID: EndpointID,
        cancellationToken token: CancellationToken
    ) {
        // Reassemble the STREAM payload (a single large message) off the delegate queue; forward it only if the
        // transfer completed (EOF without a read error and no failure/cancel update), like the Android transport.
        // The box hands the (non-Sendable) stream to the single reader task; it is not touched elsewhere.
        withLock { _ = incomingStreams.insert(payloadID) }
        let streamBox = UncheckedSendableBox(stream)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let stream = streamBox.value
            var data = Data()
            var complete = false
            stream.open()
            defer { stream.close() }
            let bufferSize = 64 * 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while true {
                let readCount = stream.read(&buffer, maxLength: bufferSize)
                if readCount < 0 { break }  // Read error: aborted transfer
                if readCount == 0 {  // EOF: the transfer finished
                    complete = true
                    break
                }
                data.append(buffer, count: readCount)
                if data.count > Self.extendedMessageSizeLimit { break }  // Oversized: drop
            }
            guard let self = self, self.finishIncomingStream(payloadID, complete: complete) else { return }
            self.bridge?.messageReceived(endpointId: endpointID, data: data)
        }
    }

    /// Unregisters a finished incoming stream; returns whether its data may be forwarded.
    private func finishIncomingStream(_ payloadID: PayloadID, complete: Bool) -> Bool {
        return withLock {
            _ = incomingStreams.remove(payloadID)
            let aborted = abortedIncomingStreams.remove(payloadID) != nil
            return complete && !aborted
        }
    }

    public func connectionManager(
        _ connectionManager: ConnectionManager,
        didStartReceivingResourceWithID payloadID: PayloadID,
        from endpointID: EndpointID, at localURL: URL, withName name: String,
        cancellationToken token: CancellationToken
    ) {
        // FILE payloads are not used by the mesh protocol (yet)
    }

    public func connectionManager(
        _ connectionManager: ConnectionManager,
        didReceiveTransferUpdate update: TransferUpdate,
        from endpointID: EndpointID, forPayload payloadID: PayloadID
    ) {
        switch update {
        case .failure, .canceled:
            // An incoming STREAM whose transfer failed must not be forwarded (the reader checks this at its end)
            withLock {
                if incomingStreams.contains(payloadID) { _ = abortedIncomingStreams.insert(payloadID) }
            }
        default:
            break  // Progress is not needed; send outcomes are reported via the send completion handlers
        }
    }

    public func connectionManager(
        _ connectionManager: ConnectionManager, didChangeTo state: ConnectionState,
        for endpointID: EndpointID
    ) {
        switch state {
        case .connecting:
            break
        case .connected:
            withLock {
                _ = connectedEndpoints.insert(endpointID)
                _ = outgoingRequests.remove(endpointID)
            }
            bridge?.connectionResult(endpointId: endpointID, success: true)
        case .rejected:
            withLock { _ = outgoingRequests.remove(endpointID) }
            bridge?.connectionResult(endpointId: endpointID, success: false)
        case .disconnected:
            let wasConnected = withLock { () -> Bool in
                _ = outgoingRequests.remove(endpointID)
                return connectedEndpoints.remove(endpointID) != nil
            }
            if wasConnected {
                bridge?.disconnected(endpointId: endpointID)
            } else {
                bridge?.connectionResult(endpointId: endpointID, success: false)
            }
        }
    }
}

// MARK: - Endpoint metadata coding (wire compatibility with the Android transport)

extension NearbyMeshNetwork {

    private static let hexDigits = Array("0123456789ABCDEF".utf8)

    /// Encodes endpoint metadata (advertising/connection info) the way the Android transport does: as an
    /// upper-case hex string (ASCII bytes). Nearby surfaces this metadata to Android peers via the String endpoint
    /// *name*, which cannot carry arbitrary binary data; hex is charset-agnostic on both sides (see the mesh
    /// design doc, "Endpoint name vs. endpoint info"). Doubles the size; Nearby caps endpoint info at 131 bytes.
    static func encodeEndpointInfo(_ bytes: Data) -> Data {
        var hex = Data(capacity: bytes.count * 2)
        for byte in bytes {
            hex.append(hexDigits[Int(byte >> 4)])
            hex.append(hexDigits[Int(byte & 0x0F)])
        }
        return hex
    }

    /// Decodes hex-encoded endpoint metadata received from a peer (either case). Malformed input yields empty
    /// data, which the core rejects gracefully via its magic-header check (mirrors Android's hexToBytes()).
    static func decodeEndpointInfo(_ hex: Data) -> Data {
        guard !hex.isEmpty, hex.count % 2 == 0 else { return Data() }
        var bytes = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            guard let high = hexValue(hex[index]), let low = hexValue(hex[index + 1]) else { return Data() }
            bytes.append(high << 4 | low)
            index += 2
        }
        return bytes
    }

    private static func hexValue(_ char: UInt8) -> UInt8? {
        switch char {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return char - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return char - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return char - UInt8(ascii: "a") + 10
        default: return nil
        }
    }
}
