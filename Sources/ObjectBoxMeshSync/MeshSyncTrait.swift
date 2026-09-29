//
// Copyright (c) 2026 ObjectBox. https://objectbox.io
//

// In the ObjectBox Swift package (objectbox-swift-spm), the ObjectBoxMeshSync product only pulls in Google's
// NearbyConnections package when the package's "MeshSync" trait is enabled, so that users of the other products
// never fetch it. Without the trait the sources cannot compile (no NearbyConnections module); fail with a clear
// message instead of a puzzling one. The add-on's own development package defines MeshSync unconditionally.
#if !MeshSync
    #error(
        "ObjectBoxMeshSync needs the ObjectBox package's MeshSync trait: add traits: [\"MeshSync\"] to the dependency")
#endif
