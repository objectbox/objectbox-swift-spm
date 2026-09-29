//
// Copyright (c) 2026 ObjectBox. https://objectbox.io
//

import Foundation
import NearbyConnections
import ObjectBox

/// Experimental: entry point for Google-Nearby-based peer-to-peer mesh sync on Apple platforms
/// (the analog of `AndroidMeshSync` in the objectbox-meshsync-android add-on).
///
/// ```swift
/// let configuration = Sync.Configuration(store: store, url: "wss://server.example.com")
/// configuration.credentials = [.none()]
/// let meshConfig = try AppleMeshSync.createConfig(meshId: "com.example.myapp.mesh")
/// meshConfig.nearbyMediums = [.wifiLAN]  // Optional: Nearby-specific settings live on the config, too
/// configuration.mesh = meshConfig
/// let client = try Sync.makeClient(configuration: configuration)
/// try client.start()  // The mesh starts and stops together with the sync client
/// ```
///
/// Info.plist requirements (the analog of the merged Android manifest permissions):
/// `NSLocalNetworkUsageDescription`, the Bonjour service entries used by Nearby Connections
/// (`NSBonjourServices`), and `NSBluetoothAlwaysUsageDescription`.
public enum AppleMeshSync {

    /// Creates a mesh configuration with a Nearby Connections transport registered.
    /// Create a new configuration for each sync client: a mesh network serves at most one client over its lifetime.
    /// Optional settings are properties of the returned ``MeshConfig``: the general ones (e.g. connection limits
    /// and timings) and the Nearby-specific ``MeshConfig/nearbyMediums``.
    /// - Parameter meshId: the mesh network identifier; nodes with different IDs ignore each other.
    ///   Doubles as the Nearby service ID (use something app-specific, e.g. "com.example.myapp.mesh").
    public static func createConfig(meshId: String) throws -> MeshConfig {
        let transport = NearbyMeshNetwork()
        let network = try MeshNetwork(
            type: .appleNearby,
            messageSizeLimit: NearbyMeshNetwork.messageSizeLimit,
            extendedMessageSizeLimit: NearbyMeshNetwork.extendedMessageSizeLimit,
            transport: transport)
        transport.bridge = network
        let config = MeshConfig(meshId: meshId)
        config.add(network: network)
        return config
    }
}

extension MeshConfig {

    /// The Nearby transport registered by ``AppleMeshSync/createConfig(meshId:)``, nil if this config has none.
    var nearbyTransport: NearbyMeshNetwork? {
        networks.lazy.compactMap { $0.transport as? NearbyMeshNetwork }.first
    }

    /// Optionally restricts the Nearby mediums used for advertising and discovery; nil (the default) does not
    /// restrict them, Nearby then uses all mediums it supports. E.g. `[.wifiLAN]` avoids Bluetooth (including its
    /// permission prompt) when all nodes share a network. Set it before starting the sync client; later changes
    /// are ignored. Nearby-specific, thus only available on Apple platforms (Android's Nearby API does not offer
    /// medium selection). Reads and writes go to the Nearby transport of this config (see
    /// ``NearbyMeshNetwork/mediums``); without one, reads give nil and writes do nothing.
    public var nearbyMediums: Set<Medium>? {
        get { nearbyTransport?.mediums }
        set { nearbyTransport?.mediums = newValue }
    }
}
